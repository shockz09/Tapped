# TypingStats

A minimal macOS menubar app that tracks your daily keystrokes with iCloud sync across devices.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Live keystroke counter** in the menubar (keyboard icon + count)
- **Daily statistics**: Today, Yesterday, 7-day avg, 30-day avg, Record
- **History window** with visual bar charts
- **iCloud sync** across all your Macs using CRDT (Conflict-free Replicated Data Types)
- **Start at Login** option
- **No Xcode required** - builds with Swift Package Manager
- **Privacy-focused** - all data stays in your iCloud, no third-party servers

## Screenshot

<!-- Add screenshot here -->

## Installation

### Download

Download the latest release from the [Releases](../../releases) page.

### Build from Source

Requirements:
- macOS 13+
- Swift 5.9+

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/TypingStats.git
cd TypingStats

# Build
swift build -c release

# Copy to Applications (optional)
cp -r .build/release/TypingStats /Applications/
```

Or use the included app bundle:

```bash
swift build
cp .build/debug/TypingStats TypingStats.app/Contents/MacOS/
open TypingStats.app
```

## How It Works

### Keystroke Monitoring

Uses `CGEventTap` to listen for keyboard events system-wide. This requires **Accessibility permission** which you'll be prompted to grant on first launch.

### CRDT Sync

Each device maintains a G-Counter (Grow-only Counter) for keystroke tracking. When syncing via iCloud:

```
Device A: {A: 100, B: 50}
Device B: {A: 80, B: 70}
Merged:   {A: 100, B: 70}  // max() of each device's count
```

This ensures counts always converge correctly regardless of sync order or timing - no conflicts possible!

### Data Storage

- **Local**: `~/Library/Application Support/TypingStats/`
- **iCloud**: `NSUbiquitousKeyValueStore` (automatic, up to 1MB)

## Project Structure

```
Sources/TypingStats/
├── TypingStatsApp.swift      # App entry point & menu
├── Core/
│   ├── KeystrokeMonitor.swift    # CGEventTap wrapper
│   ├── PermissionManager.swift   # Accessibility permissions
│   └── StatusItemManager.swift   # Menubar icon + count
├── Data/
│   ├── GCounter.swift            # CRDT implementation
│   ├── DailyStats.swift          # Daily record model
│   ├── DeviceID.swift            # Hardware UUID
│   ├── LocalStore.swift          # JSON persistence
│   ├── iCloudSync.swift          # iCloud key-value store
│   └── StatsRepository.swift     # Data coordinator
└── UI/
    └── HistoryWindow.swift       # History view
```

## Privacy

TypingStats:
- Only counts keystrokes, never records what you type
- Stores data locally and in your personal iCloud
- Has no analytics, telemetry, or network calls (except iCloud sync)
- Is fully open source for you to audit

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- [Multi.app](https://multi.app/blog/pushing-the-limits-nsstatusitem) for the NSStatusItem + NSHostingView technique
