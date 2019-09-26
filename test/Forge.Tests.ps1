Import-Module (Join-Path $PSScriptRoot "../UniversalDashboard.Forge.psm1") -Force
New-UDDesktopApp -Name "MyApp" -Path (Join-Path $PSScriptRoot "dashboard.ps1") -OutputPath "$PSScriptRoot/Out"