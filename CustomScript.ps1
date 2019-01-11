<# Custom Script for Windows to configure FreeSWITCH using data from Azure ARM template parameters #>
param (
    [string]$pemdata,
    [string]$hostname,
    [string]$httpuser,
    [string]$httppass,
	[string]$msipackagesource,
	[string]$freeswitchmsifile
)

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
