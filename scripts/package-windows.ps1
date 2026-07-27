$ErrorActionPreference = "Stop"

Set-Location (Split-Path -Parent $PSScriptRoot)

$installerScript = Join-Path $PWD "installer\windows\inno\Screenscrab.iss"
if (-not (Test-Path $installerScript)) {
    throw "Installer script not found: $installerScript"
}

$iscc = Get-Command "ISCC.exe" -ErrorAction SilentlyContinue
if ($null -ne $iscc) {
    & $iscc.Source $installerScript
    Write-Host "Windows installer packaged."
    return
}

$makensis = Get-Command "makensis.exe" -ErrorAction SilentlyContinue
if ($null -ne $makensis) {
    Write-Warning "NSIS detected, but this repo currently ships an Inno Setup script. Use ISCC.exe for the installer build."
    return
}

Write-Host "Packaging is scripted through Inno Setup in a local environment."
Write-Host "Install Inno Setup and run: ISCC.exe $installerScript"
