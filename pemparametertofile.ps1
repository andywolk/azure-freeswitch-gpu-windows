<# Custom Script for Windows to install a PEM file from Azure ARM template parameter #>
param (
    [string]$pemdata
)

$dest = "C:\Program Files\FreeSWITCH\cert"
New-Item -Path $dest -ItemType directory
$pemdata | Out-File -encoding ASCII "$dest\verto.pem"