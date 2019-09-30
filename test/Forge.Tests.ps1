Import-Module "$PSScriptRoot/../UniversalDashboard.Forge.psd1" -Force
New-UDDesktopApp -Name "MyApp" -Path "$PSScriptRoot/dashboard" -OutputPath "./Out" -Verbose