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

    .PARAMETER IconUrl
    A web URL to an .ICO file to use as the icon displayed in "Programs and Features."

    If not specified, the Atom logo will be used.

    .PARAMETER SetupIcon
    The .ICO file used as the icon on the generated install file.

    Must be a path to the file on a local disk.

    .PARAMETER LoadingGif
    The local path to a .GIF to be displayed as a splash while installing your generated application.

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
        $PowerShellHost = "pwsh",
        [Parameter()]
        $IconUrl,
        [Parameter()]
        $SetupIcon,
        [Parameter()]
        $LoadingGif
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
        $Content = @"
{0} = {0} + "; {1}"
Import-Module UniversalDashboard

$Content
"@ -f '$Env:PSModulePath', '$PSScriptRoot'
        $Content | Out-File (Join-Path $Src "dashboard.ps1") -Force -Encoding utf8

        Copy-Item -Path (Join-Path $PSScriptRoot "index.js" ) -Destination $src -Force
        $IndexJs = Join-Path $src "index.js"

        $port = Get-PortNumber -Path $Dashboard
        Set-ForgeVariable -IndexPath $IndexJs -PowerShellHost $PowerShellHost -Port $port

        $PackageConfig = [IO.Path]::Combine($OutputPath, $Name, 'package.json')
        $SquirrelSplat = @{'ConfigPath' = $PackageConfig}
        if ($IconUrl) {$SquirrelSplat['IconUrl'] = $IconUrl}
        if ($SetupIcon) {$SquirrelSplat['SetupIcon'] = $SetupIcon}
        if ($LoadingGif) {$SquirrelSplat['LoadingGif'] = $LoadingGif}
        Set-SquirrelConfig @SquirrelSplat

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

    $UniversaDashboard = Get-Module -Name UniversalDashboard #-ListAvailable

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

function Set-SquirrelConfig {
    param(
        [Parameter(Mandatory)]
        $ConfigPath,

        $IconUrl,

        $SetupIcon,

        $LoadingGif
    )

    $Content = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
    $SquirrelConfig = $Content.config.forge.makers | Where-Object {$_.name -like '*squirrel'}

    if ($IconUrl) {
        Write-Verbose "Setting SquirrelConfig IconUrl: $IconUrl"
        $SquirrelConfig.config | Add-Member -MemberType NoteProperty -Name 'iconUrl' -Value $IconUrl
    }

    if ($SetupIcon) {
        Write-Verbose "Setting SquirrelConfig SetupIcon: $SetupIcon"
        $SquirrelConfig.config | Add-Member -MemberType NoteProperty -Name 'setupIcon' -Value $SetupIcon
    }

    if ($LoadingGif) {
        Write-Verbose "Setting SquirrelConfig LoadingGif: $LoadingGif"
        $SquirrelConfig.config | Add-Member -MemberType NoteProperty -Name 'loadingGif' -Value $LoadingGif
    }

    $Content | ConvertTo-Json -Depth 10 | Out-File -FilePath $ConfigPath -Force -Encoding utf8
}
