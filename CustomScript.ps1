<# Custom Script for Windows to configure FreeSWITCH using data from Azure ARM template parameters #>
param (
    [string]$hostname,
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

$env:COMPUTERNAME | Out-File -encoding ASCII "$dest\computername.txt"
[System.Net.Dns]::GetHostName() | Out-File -encoding ASCII "$dest\hostname.txt"

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

<# Enable FreeSWITCH service to start with the system #>
Set-Service -Name "FreeSWITCH" -StartupType Automatic

<# Start FreeSWITCH service! #>
Start-Service -Name "FreeSWITCH"
