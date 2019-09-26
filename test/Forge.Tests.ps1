Import-Module "$PSScriptRoot/../UniversalDashboard.Forge.psd1" -Force
New-UDDesktopApp -Name "MyApp" -Path "$PSScriptRoot/dashboard.ps1" -OutputPath "./Out" -Verbose