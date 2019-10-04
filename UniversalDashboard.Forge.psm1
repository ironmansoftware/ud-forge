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
            $dashboard = Join-Path $PathInfo.FullName "dashboard.ps1"
            if (-not (Test-Path $dashboard))
            {
                throw "No dashboard.ps1 found in $Path"
            }
        }
        else
        {
            $dashboard = $Path
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
            Copy-Item -Path "$($PathInfo.FullName)/*" -Destination $src -Exclude (Split-Path $OutputPath -Leaf) -Recurse
        }

        Write-Verbose "Copying dashboard and index.js to electron src folder: $src"

        $content = Get-Content $dashboard -Raw
        $content = @"
{0} = {0} + "; {1}"
Import-Module UniversalDashboard

{2}
"@ -f '$Env:PSModulePath', '$PSScriptRoot', $content

        $content | Out-File (Join-Path $src "dashboard.ps1") -Force -Encoding utf8

        Copy-Item -Path (Join-Path $PSScriptRoot "index.js" ) -Destination $src -Force
        $indexJs = Join-Path $src "index.js"

        $port = Get-PortNumber -Path $dashboard
        Set-ForgeVariable -IndexPath $indexJs -PowerShellHost $PowerShellHost -Port $port

        $packageConfig = [IO.Path]::Combine($OutputPath, $Name, 'package.json')
        $squirrelSplat = @{'ConfigPath' = $packageConfig}
        if ($IconUrl) {$squirrelSplat['IconUrl'] = $IconUrl}
        if ($SetupIcon) {
            $iconPath = (Get-ChildItem -Path $src -Filter (Split-Path $SetupIcon -Leaf) -Recurse).FullName
            $squirrelSplat['SetupIcon'] = $iconPath
        }
        if ($LoadingGif) {
            $gifPath = (Get-ChildItem -Path $src -Filter (Split-Path $LoadingGif -Leaf) -Recurse).FullName
            $squirrelSplat['LoadingGif'] = $gifPath
        }
        Set-SquirrelConfig @squirrelSplat

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

    $UniversalDashboard = (Get-Module -Name UniversalDashboard -ListAvailable)[0]

    if ($null -eq $UniversalDashboard)
    {
        throw "You need to install UniversalDashboard: Install-Module UniversalDashboard -Scope CurrentUser -AcceptLicense"
    }

    $Directory = Split-Path $UniversalDashboard.Path -Parent

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

    $content = Get-Content -Path $IndexPath -Raw

    Write-Verbose "Setting ForgeVariable PowerShellHost: $PowerShellHost"
    $content = $content.Replace('$PowerShellHost', $PowerShellHost)

    Write-Verbose "Setting ForgeVariable Port: $Port"
    $content = $content.Replace('$Port', $Port)

    $content | Out-File -FilePath $IndexPath -Force -Encoding utf8
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

    $content = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
    $squirrelConfig = $Content.Config.Forge.Makers.Where({$_.Name -like '*squirrel'}).Config
    $keys = $PSBoundParameters.Keys.Where({$_ -ne 'ConfigPath'})

    foreach ($parameter in $keys) {
        Write-Verbose ('Setting SquirrelConfig {0}: {1}' -f $parameter, $PSBoundParameters[$parameter])
        $name = $parameter -replace '^\w', $parameter.Substring(0, 1).ToLower()
        $squirrelConfig | Add-Member -MemberType NoteProperty -Name $name -Value $PSBoundParameters[$parameter]
    }

    $Content | ConvertTo-Json -Depth 10 | Out-File -FilePath $ConfigPath -Force -Encoding utf8
}
