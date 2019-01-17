<# Custom Script for Windows to configure FreeSWITCH using data from Azure ARM template parameters #>
param (
    [string]$pemdata,
    [string]$hostname,
    [string]$httpuser,
    [string]$httppass,
	[string]$msipackagesource,
	[string]$freeswitchmsifile
)

New-NetFirewallRule -DisplayName 'FreeSWITCH Server ports' -Direction Inbound -Action Allow -Protocol TCP -LocalPort @('8021', '8082', '10000-30000')
New-NetFirewallRule -DisplayName 'FreeSWITCH Monitoring port' -Direction Inbound -Action Allow -Protocol TCP -LocalPort @('8088')

<# Create a folder for a PEM file #>
$pemdest = "C:\Program Files\FreeSWITCH\cert"
New-Item -Path $pemdest -ItemType directory

<# Create a folder to store FreeSWITCH msi package #>
$dest = "C:\freeswitchmsi"
New-Item -Path $dest -ItemType directory

<# HTTP AUTH #>
$pair = "${httpuser}:${httppass}"
$encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
$basicAuthValue = "Basic $encodedCreds"
$Headers = @{
    Authorization = $basicAuthValue
}

<# Speed up downloading #>
$ProgressPreference = 'SilentlyContinue'

<# Install a PEM file from Azure ARM template parameter or attempt downloading if none provided #>
IF([string]::IsNullOrWhiteSpace($pemdata)) {            
	$source = "${msipackagesource}verto.pem"    	
	Invoke-WebRequest -Uri $source -Headers $Headers -OutFile "${pemdest}\verto.pem"
} else {            
    $pemdata | Out-File -encoding ASCII "$dest\verto.pem"
}   

<# Download FreeSWITCH msi package #>
$source = "${msipackagesource}${freeswitchmsifile}"

<# Start downloading #>
Invoke-WebRequest -Uri $source -Headers $Headers -OutFile "$dest\$freeswitchmsifile"

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
            checksoftware 
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

<# Replace default vanilla configuration #>
<# Download vanilla zip #>
$source = "${msipackagesource}conf/vanilla.zip"

<# Start downloading #>
Invoke-WebRequest -Uri $source -Headers $Headers -OutFile "$dest\vanilla.zip"

<# Remove old vanilla #>
Remove-Item –path "C:\Program Files\FreeSWITCH\conf" –recurse

<# Extract vanilla.zip #>
Expand-Archive -Path "$dest\vanilla.zip" -DestinationPath "$dest"

Move-Item -Path "$dest\freeswitch\conf\vanilla"  -destination "C:\Program Files\FreeSWITCH\conf" -force

<# Start downloading Ruby #>
$rubyurl="https://github.com/oneclick/rubyinstaller2/releases/download/RubyInstaller-2.6.0-1/rubyinstaller-devkit-2.6.0-1-x64.exe"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $rubyurl -OutFile "$dest\ruby.exe"

<# Install Ruby #>
$spath="$dest\ruby.exe"
$status=Start-Process -FilePath "$dest\ruby.exe" -ArgumentList '/verysilent' -Wait -PassThru -Verb "RunAs" 

<# Enable FreeSWITCH service to start with the system #>
Set-Service -Name "FreeSWITCH" -StartupType Automatic

<# Start FreeSWITCH service! #>
Start-Service -Name "FreeSWITCH"