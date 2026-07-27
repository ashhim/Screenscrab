# Setup

## Windows

1. Install Flutter and Visual Studio 2022 with C++ desktop tools.
2. Install CMake.
3. Run:

```powershell
.\scripts\bootstrap.ps1
.\scripts\build-windows.ps1
```

## Android

1. Install Flutter, Android SDK, and JDK 17.
2. Accept Android SDK licenses.
3. Run:

```powershell
.\scripts\bootstrap.ps1
.\scripts\build-android.ps1
```

## Tailscale

Sign the devices into the same tailnet. Screenscrab connects directly to the target device address and does not manage Tailscale credentials.
