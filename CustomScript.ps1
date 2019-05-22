<# Custom Script for Windows to configure FreeSWITCH using data from Azure ARM template parameters #>
param (
    [string]$email,
    [string]$hostname,
    [string]$msipackagesource,
    [string]$freeswitchmsifile,
    [string]$adminuser,
    [string]$adminpass,
    [string]$fqdn
)

<# Add nvidia-smi to the path #>
### Modify a system environment variable ###
[Environment]::SetEnvironmentVariable
     ("Path", $env:Path, [System.EnvironmentVariableTarget]::Machine)
### Modify a user environment variable ###
[Environment]::SetEnvironmentVariable
     ("INCLUDE", $env:INCLUDE, [System.EnvironmentVariableTarget]::User)
### Usage from comments - add to the system environment variable ###
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Program Files\NVIDIA Corporation\NVSMI\", [EnvironmentVariableTarget]::Machine)

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
Get-ACMECertificate fs-verto-domain -ExportKeyPEM "$dest\key_Pkcs1.pem" -ExportCertificatePEM "$dest\cert.pem" -ExportIssuerPEM "$dest\issuer.pem" -ExportPkcs12 "$dest\cert.pfx"

Install-Module -Name PSPKI -Force
Import-Module PSPKI
Convert-PfxToPem -InputFile "$dest\cert.pfx" -OutputFile key.pem Pkcs8

<# Combine pem files to a bundle #>
$pem = Get-Content -Path $dest\key.pem
$pem | Out-File -encoding ASCII $dest\wss.pem

$pem = Get-Content -Path $dest\cert.pem
Add-Content -Path $dest\wss.pem -Value $pem

$pem = Get-Content -Path $dest\issuer.pem
Add-Content -Path $dest\wss.pem -Value $pem

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

Rename-Item -Path "C:\Program Files\FreeSWITCH\conf\sip_profiles\external-ipv6.xml" -NewName "external-ipv6.xml-disabled"
Rename-Item -Path "C:\Program Files\FreeSWITCH\conf\sip_profiles\internal-ipv6.xml" -NewName "internal-ipv6.xml-disabled"

Copy-Item "$dest\wss.pem" -Destination "$pemdest" -Force

<# Enable FreeSWITCH service to start with the system #>
Set-Service -Name "FreeSWITCH" -StartupType Automatic

<# Start FreeSWITCH service! #>
Start-Service -Name "FreeSWITCH"
