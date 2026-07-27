# Screenscrab

Screenscrab is a personal-use remote desktop system built as a monorepo with:

- `apps/windows`: Flutter desktop UI for Windows host/client mode
- `apps/android`: Flutter client app for Android
- `engine/windows`: native C++ engine for Windows capture, transport, and input
- `shared`: cross-platform protocol and data models
- `installer`: packaging assets and installer scripts
- `scripts`: terminal-first build and packaging automation

## Current architecture

The repo is organized to keep UI, protocol, and native performance code separated:

- Flutter handles screens, settings, and session controls.
- Native C++ owns the Windows runtime engine entrypoints.
- Android uses Flutter for UI and Kotlin platform channels for device features.
- Tailscale is treated as the secure device-to-device network, not as product logic.

## Supported modes

- Windows app: host mode and client mode
- Android app: client mode only

## Build prerequisites

- Flutter 3.29.x or newer
- Dart 3.7.x
- Android SDK and an installed JDK for Android builds
- Visual Studio 2022 with the Desktop development with C++ workload for Windows builds
- CMake 3.28+ for the Windows engine
- Inno Setup or NSIS if you want a packaged Windows installer

## Build

Run from PowerShell at the repo root:

```powershell
.\scripts\bootstrap.ps1
.\scripts\build-windows.ps1
.\scripts\build-android.ps1
```

## Packaging

```powershell
.\scripts\package-windows.ps1
.\scripts\package-android.ps1
```

## Notes

- This repo intentionally avoids Electron and a backend server.
- The Windows engine is scaffolded for direct native implementation of capture, encoding, audio, input, clipboard, and transfer.
- The Android client includes native bridge scaffolding for decoding, playback, and input translation.
- Some platform-specific behaviors require final machine-local SDKs and drivers to fully validate.
