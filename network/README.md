# Screenscrab Network Runtime

This module is the embedded tailnet networking layer for Screenscrab.

Target responsibilities:
- in-app sign-in flow
- tailnet node lifecycle
- peer discovery
- secure session transport
- reconnect
- status reporting

Implementation target:
- Go `tsnet` service
- C ABI bridge for the Windows engine and Flutter UI

The current repository state includes the boundary but not the final linked Go runtime yet.
