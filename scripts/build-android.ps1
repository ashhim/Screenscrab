$ErrorActionPreference = "Stop"

Set-Location (Split-Path -Parent $PSScriptRoot)

Push-Location "apps/android"
flutter build apk --release
Pop-Location

Write-Host "Android APK build complete."
