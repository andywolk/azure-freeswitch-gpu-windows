<# Custom Script for Windows to install a PEM file from Azure ARM template parameter #>
param (
    [string]$pemdata
)

$dest = "C:\Program Files\FreeSWITCH\cert"
New-Item -Path $dest -ItemType directory
$pemdata | Out-File -encoding ASCII "$dest\verto.pem"

$dest = "C:\freeswitchmsi"
New-Item -Path $dest -ItemType directory

$freeswitchmsi = "FreeSWITCH-1.8.4-x64-Release.msi"
$source = "http://files.freeswitch.org/windows/installer/x64/$freeswitchmsi"
Invoke-WebRequest $source -OutFile "$dest\$freeswitchmsi"

$spath="$dest\$freeswitchmsi"

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