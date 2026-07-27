$ErrorActionPreference = "Stop"

Set-Location (Split-Path -Parent $PSScriptRoot)

$goExe = "C:\Program Files\Go\bin\go.exe"
if (-not (Test-Path $goExe)) {
    throw "Go toolchain not found at $goExe"
}

function Find-VSWhere {
    $candidates = @(
        "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe",
        "C:\Program Files\Microsoft Visual Studio\Installer\vswhere.exe"
    )
    foreach ($path in $candidates) {
        if (Test-Path $path) {
            return $path
        }
    }
    return $null
}

function Find-VcVarsAll {
    param([string]$VsWherePath)
    if ($null -eq $VsWherePath) {
        return $null
    }
    $installPath = & $VsWherePath -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ([string]::IsNullOrWhiteSpace($installPath)) {
        return $null
    }
    $candidate = Join-Path $installPath "VC\Auxiliary\Build\vcvarsall.bat"
    if (Test-Path $candidate) {
        return $candidate
    }
    return $null
}

function Invoke-NetworkBuild {
    param(
        [string]$GoExePath,
        [string]$NetworkRootPath
    )

    $networkOut = Join-Path $NetworkRootPath "out"
    $tmpCgoDir = Join-Path $NetworkRootPath ".tmp-cgo"
    New-Item -ItemType Directory -Force -Path $networkOut | Out-Null
    New-Item -ItemType Directory -Force -Path $tmpCgoDir | Out-Null

    $env:CGO_ENABLED = "1"
    $env:GOTMPDIR = $tmpCgoDir
    Push-Location $NetworkRootPath
    try {
        & $GoExePath build -buildmode=c-shared -o (Join-Path $networkOut "screenscrab_network.dll") ./capi
    } finally {
        Pop-Location
    }
}

$vsWhere = Find-VSWhere
$vcVarsAll = Find-VcVarsAll -VsWherePath $vsWhere
$networkRoot = Join-Path $PWD "network"

if ($null -ne $vcVarsAll) {
    $tempScript = Join-Path $env:TEMP "screencrab_network_build.cmd"
    $escapedGo = $goExe.Replace('"', '""')
    $escapedRoot = $networkRoot.Replace('"', '""')
    $escapedCmd = @"
@echo off
call `"$vcVarsAll`" x64
set CGO_ENABLED=1
cd /d `"$escapedRoot`"
`"$escapedGo`" build -buildmode=c-shared -o `"$escapedRoot\out\screencrab_network.dll`" ./capi
"@
    Set-Content -LiteralPath $tempScript -Value $escapedCmd -Encoding ASCII
    & cmd /c $tempScript
    Remove-Item -LiteralPath $tempScript -Force -ErrorAction SilentlyContinue
} else {
    $gcc = Get-Command gcc -ErrorAction SilentlyContinue
    $clang = Get-Command clang -ErrorAction SilentlyContinue
    if ($null -eq $gcc -and $null -eq $clang) {
        throw "No supported C compiler found. Install MSVC Build Tools, clang, or gcc."
    }
    Invoke-NetworkBuild -GoExePath $goExe -NetworkRootPath $networkRoot
}

Write-Host "Embedded network runtime build complete."
