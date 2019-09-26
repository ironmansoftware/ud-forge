function New-UDDesktopApp {
    param(
        $Path, 
        $Name,
        $OutputPath
    )

    $Npx = Get-Command npx 
    if ($null -eq $Npx)
    {
        throw "NodeJS is required to run New-UDDesktopApp. Download here: https://nodejs.org"
    }

    if ($null -eq $OutputPath)
    {
        $OutputPath = $PSScriptRoot
    }

    if (Test-Path (Join-Path $OutputPath $Name))
    {
        Remove-Item (Join-Path $OutputPath $Name) -Force -Recurse
    }

    if (-not (Test-Path $OutputPath))
    {
        New-Item -Path $OutputPath -ItemType Directory | Out-Null
    }

    Set-Location $OutputPath
    npx create-electron-app $Name

    $src = [IO.Path]::Combine($OutputPath, $Name, 'src')

    Copy-Item -Path $Path -Destination $src
    Copy-Item -Path (Join-Path $PSScriptRoot "index.js" ) -Destination $src -Force

    npm i -g @electron-forge/cli
    Set-Location (Join-Path $OutputPath $Name)
    electron-forge make
}