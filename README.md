# Saunday

A macOS menu bar audio visualizer. It captures system audio in real time, runs an FFT analysis, and renders animated bars directly in the menu bar. When music is playing in Music.app, it also shows the current album artwork.

## Requirements

- macOS 14 or later
- Xcode 16 or later
- **Screen Recording permission** — required for `ScreenCaptureKit` to capture system audio
- **Automation permission** (Apple Events) — required to query Music.app for now-playing info

Both permissions are requested at first launch. If denied, the visualizer will not animate.

## Features

- Real-time audio frequency visualization (64 FFT bands → 20 display bars)
- Album artwork from Music.app displayed inline in the menu bar
- Launch at Login toggle in the status bar menu

---

## Architecture

The project uses **MVVM** with a **Composition Root** pattern suited for AppKit/SwiftUI hybrid menu bar apps.

```
macapp/
├── App/
│   ├── macappApp.swift         — @main entry point (SwiftUI App struct)
│   └── AppDelegate.swift       — Composition root: wires all singletons together
│
├── Core/
│   ├── AudioCaptureManager.swift   — System audio capture via ScreenCaptureKit
│   ├── FFTProcessor.swift          — FFT analysis using Accelerate framework
│   └── NowPlayingManager.swift     — Now-playing info from Music.app via AppleScript
│
├── ViewModel/
│   └── VisualizerViewModel.swift   — Aggregates Core data for views to consume
│
└── MenuBar/
    ├── MenuBarController.swift     — NSStatusItem setup and menu management
    └── MenuBarView.swift           — SwiftUI view rendered inside the menu bar
```

### Layer responsibilities

| Layer | Does | Does not |
|-------|------|----------|
| `App/` | App lifecycle, object graph wiring | Business logic |
| `Core/` | Audio capture, FFT, now-playing data | UI, shared state |
| `ViewModel/` | Aggregates Core → exposes to Views | Audio/capture logic |
| `MenuBar/` | Status bar UI, menu items | Audio data |

---

## Data flow

```
System Audio ──► AudioCaptureManager (SCStream, 48 kHz)
                      │
                      ▼
               FFTProcessor.process()
               64 logarithmic bands (80 Hz – 15 kHz)
                      │
                      ▼  (@Observable, published on main)
               AudioCaptureManager.barMagnitudes
                      │
                      ▼  (computed property, zero copy)
               VisualizerViewModel.barMagnitudes
                      │
                      ▼  (@Environment injection)
               MenuBarView → 20 animated Capsule bars


Music.app ──► NowPlayingManager (AppleScript + DistributedNotificationCenter)
                      │
                      ▼  (@Observable)
               NowPlayingManager.artwork
                      │
                      ▼
               VisualizerViewModel.artwork
                      │
                      ▼
               MenuBarView → album art image
```

---

## Adding new features

### New data source (e.g. Spotify integration)
1. Create a new class in `Core/` that publishes data via `@Observable`
2. Add the relevant computed properties to `VisualizerViewModel`
3. Inject the new core object in `AppDelegate` and pass it to `VisualizerViewModel`

### New menu bar UI element
- Edit `MenuBar/MenuBarView.swift` — it receives all data from `@Environment(VisualizerViewModel.self)`
- If you need write access to settings, add an `@Observable` settings class and inject it separately via `@Environment`

### New menu item
- Edit `MenuBar/MenuBarController.swift` → `setup()` method

### New visualization target (e.g. a floating window)
1. Create a new SwiftUI view in a new folder (e.g. `FloatingWindow/`)
2. Inject `VisualizerViewModel` via `.environment(viewModel)` at the call site
3. Manage the `NSPanel` or `NSWindow` lifecycle from `AppDelegate` or a dedicated controller

---

## Key technical notes

- **`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`** is set project-wide. All types are implicitly `@MainActor`. `AudioCaptureManager`'s stream callbacks are `nonisolated` and dispatch back to main manually — this is intentional and correct for `SCStreamOutput`.
- **`LSUIElement = YES`** in Info.plist hides the app from the Dock and app switcher.
- **`PBXFileSystemSynchronizedRootGroup`** (Xcode 16+) means any `.swift` file added to the `macapp/` folder tree is automatically compiled — no `.pbxproj` edits needed.
- **Launch at Login** uses `SMAppService.mainApp` (macOS 13+ API). No helper bundle required.
- **FFT config**: 2048-point FFT, Hann window, 64 logarithmic bands from 80 Hz to 15 kHz, normalized to `[0.0, 1.0]` via `(dB + 60) / 55`.
- **Now-playing artwork** has a 0.8s delay after the Music.app notification — this is intentional, as the artwork file needs time to be written before it can be read via AppleScript.

---

## Permissions (entitlements)

Defined in `macapp/macapp.entitlements`:

| Permission | Why |
|-----------|-----|
| `com.apple.security.screen-capture` (via Info.plist key) | `ScreenCaptureKit` requires it to capture system audio |
| Apple Events (`NSAppleEventsUsageDescription`) | `NowPlayingManager` queries Music.app via AppleScript |

The app does **not** use the sandbox (`com.apple.security.app-sandbox = false`) because `ScreenCaptureKit` audio capture is incompatible with the App Sandbox.
