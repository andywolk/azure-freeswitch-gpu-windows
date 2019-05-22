<# Custom Script for Windows to configure FreeSWITCH using data from Azure ARM template parameters #>
param (
    [string]$freeswitchpassword,
    [string]$email,
    [string]$hostname,
    [string]$msipackagesource,
    [string]$freeswitchmsifile,
    [string]$adminuser,
    [string]$adminpass,
    [string]$fqdn
)

<# Turn Windows Firewall off #> 
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

<# Create a folder for pngs files (required for the latency test) #>
$pngsdest = "C:\Program Files\FreeSWITCH\pngs"
New-Item -Path $pngsdest -ItemType directory

<# Create a folder for a PEM file #>
$pemdest = "C:\Program Files\FreeSWITCH\cert"
New-Item -Path $pemdest -ItemType directory

<# Add IIS role #>
Add-WindowsFeature Web-Mgmt-Tools, Web-Server
<# Configure pngs for the latency test #>
New-WebVirtualDirectory -Site "Default Web Site" -Name pngs -PhysicalPath "$pngsdest"
#Sets the Handler Mapping feature delegation to Read/Write for ACMESharp
Set-WebConfiguration //System.webServer/handlers -metadata overrideMode -value Allow -PSPath IIS:/ -verbose

<# Create a folder to store FreeSWITCH msi package #>
$dest = "C:\freeswitchmsi"
New-Item -Path $dest -ItemType directory

$hostname | Out-File -encoding ASCII "$dest\hostname.txt"
$fqdn | Out-File -encoding ASCII "$dest\fqdn.txt"

<# Install ACMESharp #>
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module -Name ACMESharp -AllowClobber -Force
Install-Module -Name ACMESharp.Providers.IIS -Force
Import-Module ACMESharp
Enable-ACMEExtensionModule -ModuleName ACMESharp.Providers.IIS
Initialize-ACMEVault
<# Get cert #>
New-ACMERegistration -Contacts mailto:$email -AcceptTos
New-ACMEIdentifier -Dns $fqdn -Alias fs-verto
Complete-ACMEChallenge -IdentifierRef fs-verto -ChallengeType http-01 -Handler iis -HandlerParameters @{ WebSiteRef = 'Default Web Site' }
Submit-ACMEChallenge -IdentifierRef fs-verto -ChallengeType http-01
sleep -s 60
Update-ACMEIdentifier -IdentifierRef fs-verto
New-ACMECertificate -Generate -IdentifierRef fs-verto -Alias fs-verto-domain
Submit-ACMECertificate -CertificateRef fs-verto-domain
Update-ACMECertificate -CertificateRef fs-verto-domain
<# Export pem files (optional, unfortunately the key file is exported in Pkcs1 format here, we can't take it) #>
Get-ACMECertificate fs-verto-domain -ExportKeyPEM "$dest\key_Pkcs1.pem" -ExportCertificatePEM "$dest\cert.pem" -ExportIssuerPEM "$dest\issuer.pem"

<# Export certificate as pfx so we could convert it to Pkcs8 key and a cert later #>
$p="supersecurepassword"
Get-ACMECertificate fs-verto-domain -ExportPkcs12 "$dest\cert.pfx" -CertificatePassword $p

<# Convert pfx file to a Pkcs8 key and a cert #>
Install-Module -Name PSPKI -Force
Import-Module PSPKI
$sp=ConvertTo-SecureString $p -asplaintext -force
Convert-PfxToPem -InputFile "$dest\cert.pfx" -Password $sp -OutputFile "$dest\keycert.pem" -OutputType Pkcs8

<# Combine key,certificate and issuer certificate into the wss.pem bundle #>
<# FYI: keycert.pem contains a key (Pkcs8 format we wanted) and a cert. #>
$pem = Get-Content -Path $dest\keycert.pem
$pem | Out-File -encoding ASCII $dest\wss.pem

$pem = Get-Content -Path $dest\issuer.pem
Add-Content -Path $dest\wss.pem -Value $pem

<# Time to download and install FreeSWITCH #>

<# Speed up downloading #>
$ProgressPreference = 'SilentlyContinue'

<# Download FreeSWITCH msi package #>
$source = "${msipackagesource}${freeswitchmsifile}"

<# Start downloading #>
Invoke-WebRequest -Uri $source -OutFile "$dest\$freeswitchmsifile"

$spath="$dest\$freeswitchmsifile"

<# Install FreeSWITCH msi package silently #>
If($global:availability -eq $null) 
{ 
    "1. Local Administrator software is not installed in this computer" 
    If(Test-Path $spath) 
        { 
            "2. MSI file is accessible from the directory " 
            $status=Start-Process -FilePath msiexec.exe -ArgumentList '/i',$spath,'/q' -Wait -PassThru -Verb "RunAs" 
            If($?) 
        { 
               "3.  $($Global:availability.DisplayName)--$($Global:availability.DisplayVersion) has been installed" 
        } 
        else{"3. Unable to install the software"} 
        }    
    Else 
        { 
               "2. Unable to access the MSI file form directory" 
        } 
} 
Else 
{ 
    "1. Local Administrator software is already existing" 
}

<# FreeSWITCH is installed but not running yet #>

<# Disable ipv6 profiles #>
Rename-Item -Path "C:\Program Files\FreeSWITCH\conf\sip_profiles\external-ipv6.xml" -NewName "external-ipv6.xml-disabled"
Rename-Item -Path "C:\Program Files\FreeSWITCH\conf\sip_profiles\internal-ipv6.xml" -NewName "internal-ipv6.xml-disabled"

<# Disable VP8 codec, leave H264 only. Change default password. #>
$filename="C:\Program Files\FreeSWITCH\conf\vars.xml"
$search ='<X-PRE-PROCESS cmd="set" data="default_password=1234"/>'
$replace='<X-PRE-PROCESS cmd="set" data="default_password=$freeswitchpassword"/>'
((Get-Content -path $filename -Raw) -replace $search,$replace) | Set-Content -Path $filename

$search ='<X-PRE-PROCESS cmd="set" data="global_codec_prefs=OPUS,G722,PCMU,PCMA,H264,VP8"/>'
$replace='<X-PRE-PROCESS cmd="set" data="global_codec_prefs=OPUS,G722,PCMU,PCMA,H264"/>'
((Get-Content -path $filename -Raw) -replace $search,$replace) | Set-Content -Path $filename

$search ='<X-PRE-PROCESS cmd="set" data="outbound_codec_prefs=OPUS,G722,PCMU,PCMA,H264,VP8"/>'
$replace='<X-PRE-PROCESS cmd="set" data="outbound_codec_prefs=OPUS,G722,PCMU,PCMA,H264"/>'
((Get-Content -path $filename -Raw) -replace $search,$replace) | Set-Content -Path $filename

$filename="C:\Program Files\FreeSWITCH\conf\autoload_configs\verto.conf.xml"
$search ='<param name="outbound-codec-string" value="opus,h264,vp8"/>'
$replace='<param name="outbound-codec-string" value="opus,h264"/>'
((Get-Content -path $filename -Raw) -replace $search,$replace) | Set-Content -Path $filename

$search ='<param name="inbound-codec-string" value="opus,h264,vp8"/>'
$replace='<param name="inbound-codec-string" value="opus,h264"/>'
((Get-Content -path $filename -Raw) -replace $search,$replace) | Set-Content -Path $filename

<# Install certificate into FreeSWITCH #>
Copy-Item "$dest\wss.pem" -Destination "$pemdest" -Force

<# Enable FreeSWITCH service to start with the system #>
Set-Service -Name "FreeSWITCH" -StartupType Automatic

<# Start FreeSWITCH service! #>
Start-Service -Name "FreeSWITCH"
