<p align="center">
  <img src=".github/assets/appicon.png" alt="LangSwitcher logo" width="120">
</p>
<h1 align="center">LangSwitcher</h1>

# LangSwitcher

A lightweight macOS menu bar utility that automatically fixes keyboard layout mistakes between English and Cyrillic (Russian / Ukrainian).

## How It Works

LangSwitcher runs silently in the menu bar and intercepts keyboard input via a global event tap. It detects layout mistakes in both directions and corrects them when you press Space or Enter:

- **Cyrillic → English** — you meant to type English but the layout was set to Russian/Ukrainian. The app converts the Cyrillic characters back to their QWERTY equivalents.
- **English → Cyrillic** — you meant to type Russian but the layout was set to English. The app converts the QWERTY characters to the corresponding Cyrillic word.

The macOS spell checker validates words before any conversion happens — only genuine mistyped words are corrected, and valid words in the current script are left alone.

After a correction, LangSwitcher automatically switches the active keyboard layout to match the corrected language so subsequent typing is in the right layout.

## Features

- **Bidirectional conversion** — Cyrillic → English and English → Cyrillic
- **Smart spell-check validation** — words are checked against macOS dictionaries (Russian, Ukrainian, Belarusian, English, etc.) to avoid false positives
- **Full ЙЦУКЕН & Ukrainian layout support** — all lowercase and uppercase characters, including `ґ`, `і`, `ї`, `є`
- **Latin lookalike handling** — correctly handles mixed-script words containing visually similar Latin/Cyrillic letters (e.g. `A`/`А`, `C`/`С`)
- **Force-convert shortcut** — instantly convert the current word without waiting for Space/Enter. Configurable in Settings with modifier-based or double-tap modes
- **Automatic layout switching** — switches to English or Cyrillic layout after a correction
- **Menu bar app** — no Dock icon, just a small keyboard icon in the status bar
- **Toggle on/off** — enable or disable from the menu
- **Welcome screen** — guides first-time users through Accessibility permission and shortcut setup

## Requirements

- macOS 13 Ventura or later
- Accessibility permission (the app prompts on first launch)

## Building

LangSwitcher uses Swift Package Manager (Swift 6.2):

```bash
swift build -c release
```

Or open the Xcode project and build from there.

> On first launch macOS may show a Gatekeeper warning. Right-click the app → **Open** to bypass it.

