<# Custom Script for Windows to configure FreeSWITCH using data from Azure ARM template parameters #>
param (
    [string]$pemdata,
    [string]$hostname,
    [string]$dnszone,
	[string]$publicipname,
    [string]$resourcegroup,
	[string]$dnszoneresourcegroup,
    [string]$httpuser="anonymous",
    [string]$httppass=""
)

<# $publicIp = Get-AzureRmPublicIpAddress -Name $publicipname -ResourceGroupName $resourcegroup #>

<# Add dns record to a zone #>
<# New-AzureRmDnsRecordSet -Name $hostname -RecordType A -ZoneName $dnszone -ResourceGroupName $dnszoneresourcegroup -Ttl 5 -DnsRecords (New-AzureRmDnsRecordConfig -IPv4Address "$publicIp") #>

<# Install a PEM file from Azure ARM template parameter #>
$dest = "C:\Program Files\FreeSWITCH\cert"
New-Item -Path $dest -ItemType directory
$pemdata | Out-File -encoding ASCII "$dest\verto.pem"

<# Create a folder to store FreeSWITCH msi package #>
$dest = "C:\freeswitchmsi"
New-Item -Path $dest -ItemType directory

<# Download FreeSWITCH msi package #>
$freeswitchmsi = "FreeSWITCH-1.8.4-x64-Release.msi"
$source = "http://${httpuser}:${httppass}@files.freeswitch.org/windows/installer/x64/$freeswitchmsi"
Invoke-WebRequest $source -OutFile "$dest\$freeswitchmsi"

$spath="$dest\$freeswitchmsi"

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