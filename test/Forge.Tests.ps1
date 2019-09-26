Import-Module (Join-Path $PSScriptRoot "../UniversalDashboard.Forge.psm1") -Force
New-UDDesktopApp -Name "Test" -Path (Join-Path $PSScriptRoot "dashboard.ps1")