# Tapped

A minimal macOS menubar app that tracks your daily keystrokes and words with iCloud sync across devices.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Live keystroke/word counter** in the menubar (keyboard icon + count)
- **Toggle between keystrokes and words** display mode
- **Daily statistics**: Today, Yesterday, 7-day avg, 30-day avg, Record
- **History window** with visual bar charts
- **iCloud sync** across all your Macs using CRDT (Conflict-free Replicated Data Types)
- **Start at Login** option
- **No Xcode required** - builds with Swift Package Manager
- **Privacy-focused** - all data stays in your iCloud, no third-party servers

## Demo



https://github.com/user-attachments/assets/2fcfd5c7-4f73-486f-b9ef-2f31dd464c05



## Installation

### Homebrew (Recommended)

```bash
brew install shockz09/tap/tapped
```

Then grant Accessibility permission when prompted on first launch.

### Manual Download

1. Download the latest `.zip` from the [Releases](../../releases) page
2. Unzip and drag `TypingStats.app` to your Applications folder
3. **First launch**: Right-click the app → "Open" (required to bypass Gatekeeper since the app is not signed)
4. Grant Accessibility permission when prompted

### Build from Source

Requirements:
- macOS 13+
- Swift 5.9+

```bash
# Clone the repository
git clone https://github.com/shockz09/TypingStats.git
cd TypingStats

# Build release version
swift build -c release

# Copy binary to app bundle and run
cp .build/release/TypingStats TypingStats.app/Contents/MacOS/
open TypingStats.app
```

## How It Works

### Keystroke Monitoring

Uses `CGEventTap` to listen for keyboard events system-wide. This requires **Accessibility permission** which you'll be prompted to grant on first launch.

### Word Counting

Counts words by detecting when you start typing a new word (transition from space/enter to a letter). Accurate for normal typing.

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

## Privacy

Tapped:
- Only counts keystrokes and words, never records what you type
- Stores data locally and in your personal iCloud
- Has no analytics, telemetry, or network calls (except iCloud sync)
- Is fully open source for you to audit

## Inspiration

I saw [@rauchg](https://github.com/rauchg) (Vercel's CEO)'s [tweet about this tool he made to count keystrokes per day](https://x.com/rauchg/status/2004621125129830729). I loved the idea and wanted to use it myself, but it wasn't available to install and wasn't open source, so I decided to build it and ship it myself.

I would love if people use this and find bugs or add features they would want to use in this!

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- [Multi.app](https://multi.app/blog/pushing-the-limits-nsstatusitem) for the NSStatusItem + NSHostingView technique
