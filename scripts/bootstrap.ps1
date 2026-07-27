$ErrorActionPreference = "Stop"

Set-Location (Split-Path -Parent $PSScriptRoot)

Write-Host "Resolving Windows app dependencies..."
Push-Location "apps/windows"
flutter pub get
Pop-Location

Write-Host "Resolving Android app dependencies..."
Push-Location "apps/android"
flutter pub get
Pop-Location

Write-Host "Resolving shared package dependencies..."
Push-Location "shared/dart"
dart pub get
Pop-Location

Write-Host "Bootstrap complete."
