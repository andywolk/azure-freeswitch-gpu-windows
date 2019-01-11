<# Custom Script executed at the end of the deployment process #>
param (

)

<# Enable FreeSWITCH service to start with the system #>
Set-Service -Name "FreeSWITCH" -StartupType Automatic

<# Start FreeSWITCH service! #>
Start-Service -Name "FreeSWITCH"