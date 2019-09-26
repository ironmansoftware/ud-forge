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
        npx create-electron-app $Name
        Pop-Location
    
        $src = [IO.Path]::Combine($OutputPath, $Name, 'src')

        Write-Verbose "Copying dashboard and index.js to electron src folder: $src"
    
        Copy-Item -Path $Path -Destination $src
        Copy-Item -Path (Join-Path $PSScriptRoot "index.js" ) -Destination $src -Force
        $IndexJs = Join-Path $src "index.js"

        Set-ForgeVariable -IndexPath $IndexJs -PowerShellHost $PowerShellHost

        Write-Verbose "Building electron app with forge"
    
        npm i -g @electron-forge/cli
        Set-Location (Join-Path $OutputPath $Name)
        electron-forge make
    }
}

function Set-ForgeVariable {
    param(
        $IndexPath,
        $PowerShellHost
    )

    $Content = Get-Content -Path $IndexPath -Raw

    Write-Verbose "Setting ForgeVariable PowerShellHost: $PowerShellHost"
    $Content = $Content.Replace('$PowerShellHost', $PowerShellHost)
    $Content | Out-File -FilePath $IndexPath -Force -Encoding utf8
}