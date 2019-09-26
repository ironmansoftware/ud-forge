# ud-forge

Build Desktop Apps with Universal Dashboard

![](./images/forge.gif)

# About

Universal Dashboard Forge uses [Electron](https://electronjs.org/) and Electron Forge to build desktops apps with Universal Dashboard. 

# Installation 

```
Install-Module UniversalDashboard.Forge
```

# Requirements

- [NodeJS ](https://nodejs.org/)

# Usage 

```
Import-Module UniversalDashboard.Forge
New-UDDesktopApp -Path .\dashboard.ps1 -OutputPath .\out -Name MyApp
.\out\MyApp\MyApp.exe
```

