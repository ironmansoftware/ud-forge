function New-UDDesktopApp {
    <#
    .SYNOPSIS
    Generate a desktop app with Universal Dashboard

    .DESCRIPTION
    Generates a desktop application with Universal Dashboard using electron.

    .PARAMETER Path
    The path to the dashboard.ps1 file you want to create an app out of.

    .PARAMETER Name
    The name of the electron application.

    .PARAMETER OutputPath
    The output path for the application.

    .EXAMPLE
    New-UDDesktopApp -Path "./dashboard.ps1" -OutputPath "./out" -Name "MyApp"

    .NOTES
    This cmdlet requires NodeJS to be installed.
    #>

    param(
        [Parameter(Mandatory)]
        $Path,
        [Parameter(Mandatory)]
        $Name,
        [Parameter()]
        $OutputPath,
        [Parameter()]
        [ValidateSet("pwsh", "powershell")]
        $PowerShellHost = "pwsh"
    )

    End {
        $provider = $null;
        $drive = $null
        $pathHelper = $ExecutionContext.SessionState.Path
        $Path = $pathHelper.GetUnresolvedProviderPathFromPSPath($Path, [ref]$provider, [ref]$drive)
        $PathInfo = Get-Item $Path

        if ($PathInfo.PSIsContainer)
        {
            Write-Verbose "Path is a directory. Locating dashboard.ps1"
            $Dashboard = Join-Path $PathInfo.FullName "dashboard.ps1"
            if (-not (Test-Path $Dashboard))
            {
                throw "No dashboard.ps1 found in $Path"
            }
        }
        else 
        {
            $Dashboard = $Path
        }

        $Npx = Get-Command npx
        if ($null -eq $Npx)
        {
            throw "NodeJS is required to run New-UDDesktopApp. Download here: https://nodejs.org"
        }

        if ($null -eq $OutputPath)
        {
            $OutputPath = $PSScriptRoot
            Write-Verbose "No output path specified. Using: $OutputPath"
        }
        else
        {
            $provider = $null;
            $drive = $null
            $pathHelper = $ExecutionContext.SessionState.Path
            $OutputPath = $pathHelper.GetUnresolvedProviderPathFromPSPath($OutputPath, [ref]$provider, [ref]$drive)
            Write-Verbose "Output path resolved to: $OutputPath"
        }

        if (Test-Path (Join-Path $OutputPath $Name))
        {
            Write-Verbose "Output path exists. Removing existing output path."
            Remove-Item (Join-Path $OutputPath $Name) -Force -Recurse
        }

        if (-not (Test-Path $OutputPath))
        {
            Write-Verbose "Output path does not exist. Creating new output path."
            New-Item -Path $OutputPath -ItemType Directory | Out-Null
        }

        Push-Location $OutputPath
        Write-Verbose "Creating electron app $Name"
        npm install create-electron-app@latest --global
        npx create-electron-app $Name
        Pop-Location

        $src = [IO.Path]::Combine($OutputPath, $Name, 'src')

        if ($PathInfo.PSIsContainer)
        {
            Write-Verbose "Copying contents of $Path to $src"
            Copy-Item -Path "$($PathInfo.FullName)/*" -Destination $src -Container -Recurse 
        }

        Write-Verbose "Copying dashboard and index.js to electron src folder: $src"

        $Content = Get-Content $Dashboard -Raw
        $Content = "
        `$Env:PSModulePath = `$Env:PSModulePath + `";`$PSScriptRoot`"
        Import-Module UniversalDashboard" + [System.Environment]::NewLine + $Content
        $Content | Out-File (Join-Path $Src "dashboard.ps1") -Force -Encoding utf8

        Copy-Item -Path (Join-Path $PSScriptRoot "index.js" ) -Destination $src -Force
        $IndexJs = Join-Path $src "index.js"

        $port = Get-PortNumber -Path $Dashboard
        Set-ForgeVariable -IndexPath $IndexJs -PowerShellHost $PowerShellHost -Port $port

        Write-Verbose "Copying Universal Dashboard to output path"

        Copy-UniversalDashboard -OutputPath $src

        Write-Verbose "Building electron app with forge"

        npm i -g @electron-forge/cli
        Set-Location (Join-Path $OutputPath $Name)
        electron-forge make
    }
}

function Copy-UniversalDashboard {
    param($OutputPath)

    $UniversaDashboard = Get-Module -Name UniversalDashboard -ListAvailable

    if ($null -eq $UniversaDashboard)
    {
        throw "You need to install UniversalDashboard: Install-Module UniversalDashboard -Scope CurrentUser -AcceptList"
    }

    $Directory = Split-Path $UniversaDashboard.Path -Parent

    $UDDirectory = Join-Path $OutputPath "UniversalDashboard"
    New-Item $UDDirectory -ItemType Directory | Out-Null

    Copy-Item $Directory -Recurse -Destination $UDDirectory
}

function Set-ForgeVariable {
    param(
        $IndexPath,
        $PowerShellHost,
        $Port
    )

    $Content = Get-Content -Path $IndexPath -Raw

    Write-Verbose "Setting ForgeVariable PowerShellHost: $PowerShellHost"
    $Content = $Content.Replace('$PowerShellHost', $PowerShellHost)

    Write-Verbose "Setting ForgeVariable Port: $Port"
    $Content = $Content.Replace('$Port', $Port)

    $Content | Out-File -FilePath $IndexPath -Force -Encoding utf8
}

function Get-PortNumber {
    param (
        $Path
    )

    $content = Get-Content -Path $Path
    $match = [regex]::Match($content, '[sS]tart-[uUdD]{3}ash.+-Port (\d+)')

    if ($match.Success) { $match.Groups[1].Value } else { 80 }
}
