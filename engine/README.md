# Engine

The native runtime is organized by responsibility:

- `capture`: frame acquisition
- `encode`: video compression
- `audio`: audio capture and playback plumbing
- `input`: keyboard and mouse injection
- `clipboard`: clipboard sync
- `transfer`: file transfer primitives
- `session`: session lifecycle and reconnect logic
- `network`: transport and discovery helpers

The Windows implementation currently lives under `engine/windows`.
The top-level module folders exist to keep the architecture explicit as the codebase expands.
