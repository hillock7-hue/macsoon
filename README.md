# FlowInk

FlowInk is the working codename for a lightweight native macOS drawing app focused on smooth SAI-like brush feel, Wacom-first input, large canvases, layers, and snapshot-based history.

## Current Prototype

The current 1.0 prototype includes:

- Native AppKit app shell.
- Metal-backed drawing canvas.
- Input abstraction for future Wacom pressure, tilt, buttons, and eraser support.
- Simulated pressure for mouse/trackpad development before PTH-660 testing.
- Basic pressure-sensitive stroke rendering.
- A first-pass adaptive stabilizer for smoother strokes.
- Per-stroke undo via the HUD button or `Cmd+Z`.
- Minimal HUD showing pressure source and input data.

## Build And Run

```bash
./scripts/run-prototype.sh
```

The script compiles `Sources/FlowInk` into `.build/FlowInkPrototype` and launches it.

Swift Package Manager metadata is present for future Xcode/SwiftPM workflows, but the direct `swiftc` script is the current reliable local path in this sandboxed workspace.

## GitHub Setup

Do not share passwords or tokens in chat.

Create an empty GitHub repository and share only the repository URL, for example:

```text
https://github.com/your-name/FlowInk.git
```

Then Codex can add it as `origin`, commit the local files, and push using the credentials already configured on this Mac.
