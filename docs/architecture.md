# Architecture

Screenscrab is split into three layers:

1. Presentation layer
   - Flutter desktop app on Windows
   - Flutter mobile app on Android

2. Shared protocol layer
   - session messages
   - device models
   - file transfer metadata
   - clipboard payloads

3. Native runtime layer
   - Windows engine in C++
   - Android native bridge in Kotlin

## Network model

The application assumes both endpoints are reachable on the same Tailscale network.
No relay service, public backend, or account database is introduced by Screenscrab.

## Windows runtime

The Windows app is designed to:

- host this machine
- connect to another host
- manage monitor selection
- exchange session messages
- expose clipboard and transfer operations

## Android runtime

The Android app is designed to:

- connect to a Windows host
- render the remote stream
- send touch, keyboard, and clipboard events
- request file transfer operations

## Deferred implementation areas

The repo includes explicit TODO markers for machine-specific behavior that depends on:

- capture backend selection
- codec availability
- input policy and elevated permissions
- lock-screen limitations on Windows
