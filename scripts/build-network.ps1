$ErrorActionPreference = "Stop"

Set-Location (Split-Path -Parent $PSScriptRoot)

$goExe = "C:\Program Files\Go\bin\go.exe"
if (-not (Test-Path $goExe)) {
    throw "Go toolchain not found at $goExe"
}

if (-not (Get-Command gcc -ErrorAction SilentlyContinue) -and -not (Get-Command clang -ErrorAction SilentlyContinue) -and -not (Get-Command cl -ErrorAction SilentlyContinue)) {
    Write-Warning "No C compiler found. Skipping embedded network DLL build."
    return
}

$networkRoot = Join-Path $PWD "network"
$networkOut = Join-Path $networkRoot "out"
New-Item -ItemType Directory -Force -Path $networkOut | Out-Null

$env:CGO_ENABLED = "1"
Push-Location $networkRoot
& $goExe build -buildmode=c-shared -o (Join-Path $networkOut "screencrab_network.dll") ./capi
Pop-Location

Write-Host "Embedded network runtime built successfully."
