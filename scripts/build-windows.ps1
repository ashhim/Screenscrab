$ErrorActionPreference = "Stop"

Set-Location (Split-Path -Parent $PSScriptRoot)

if (Get-Command cmake -ErrorAction SilentlyContinue) {
    Write-Host "Building native engine..."
    $engineRoot = Join-Path $PWD "engine\windows"
    $engineBuild = Join-Path $engineRoot "build"
    $engineOut = Join-Path $engineRoot "out"
    $appOut = Join-Path $PWD "apps\windows\build\windows\x64\runner\Release"
    New-Item -ItemType Directory -Force -Path $engineBuild | Out-Null
    New-Item -ItemType Directory -Force -Path $engineOut | Out-Null
    Push-Location "apps/windows"
    flutter build windows --release
    Pop-Location
    cmake -S $engineRoot -B $engineBuild -DCMAKE_BUILD_TYPE=Release -DSCRSCRAB_APP_RELEASE_DIR="$appOut"
    cmake --build $engineBuild --config Release
    $dll = Get-ChildItem -Path $engineOut -Filter screencrab_engine.dll | Select-Object -First 1
    if ($null -ne $dll) {
        if (Test-Path $appOut) {
            Copy-Item $dll.FullName (Join-Path $appOut "screencrab_engine.dll") -Force
        }
    } else {
        Write-Warning "Native engine DLL was not found after build."
    }
    Write-Host "Native engine build complete."
} else {
    Write-Warning "CMake is not installed. Skipping native engine build."
    Push-Location "apps/windows"
    flutter build windows --release
    Pop-Location
    Write-Host "Windows Flutter build complete."
}
