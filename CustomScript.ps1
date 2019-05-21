<# Custom Script for Windows to configure FreeSWITCH using data from Azure ARM template parameters #>
param (
    [string]$hostname,
    [string]$httpuser,
    [string]$httppass,
    [string]$msipackagesource,
    [string]$freeswitchmsifile,
    [string]$adminuser,
    [string]$adminpass
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
###New-NetFirewallRule -DisplayName 'FreeSWITCH Server ports' -Direction Inbound -Action Allow -Protocol TCP -LocalPort @('8021', '8082', '10000-30000')
###New-NetFirewallRule -DisplayName 'FreeSWITCH Monitoring port' -Direction Inbound -Action Allow -Protocol TCP -LocalPort @('8088')

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

$latencyurl="${msipackagesource}qrcodes.mp4"
Invoke-WebRequest -Uri $latencyurl -Headers $Headers -OutFile "C:\Program Files\FreeSWITCH\sounds\en\us\callie\qrcodes.mp4"

<# Enable FreeSWITCH service to start with the system #>
Set-Service -Name "FreeSWITCH" -StartupType Automatic

<# Start FreeSWITCH service! #>
Start-Service -Name "FreeSWITCH"
