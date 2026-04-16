<p align="center">
  <img src=".github/assets/appicon.png" alt="LangSwitcher logo" width="120">
</p>

<h1 align="center">LangSwitcher</h1>

<p align="center">
  A menu bar app for macOS that fixes English/Cyrillic keyboard layout mistakes while you type.
</p>

---

> [!WARNING]
> **Accessibility Permission Required**
> LangSwitcher uses the macOS Accessibility API to observe and replace keystrokes. You must grant access in **System Settings → Privacy & Security → Accessibility** before it can correct text. The app opens a setup assistant on first launch to help with this.

> [!NOTE]
> **Unsigned Local Builds**
> Builds created from source are unsigned by default. macOS may block the first launch with a *"developer cannot be verified"* warning. You can allow it from **System Settings → Privacy & Security** or remove quarantine manually with `xattr -dr com.apple.quarantine /path/to/LangSwitcher.app`.

## Overview

LangSwitcher runs as a lightweight accessory app with a menu bar icon and no Dock icon. It listens for typing events, keeps track of the current word, and corrects common keyboard-layout mistakes between English QWERTY and Cyrillic layouts when you press `Space` or `Return`.

It is designed for people who regularly switch between English and Cyrillic layouts and want layout mistakes fixed without interrupting their flow.

## Features

| Feature | Details |
|---|---|
| **Automatic layout correction** | Fixes mistyped words on `Space` or `Return` by converting between English and Cyrillic keyboard positions |
| **Force Convert shortcut** | Lets you flip the current word immediately without waiting for a word boundary |
| **Configurable shortcut recorder** | Includes a first-run setup flow and Preferences UI for recording or changing the force-convert shortcut |
| **Text shortcuts** | Expands custom triggers such as `mymail` into longer phrases or snippets |
| **Mixed-script validation** | Detects valid Cyrillic words even when they include Latin lookalikes such as `m` in `дom`-style mistakes |
| **Apostrophe and hyphen support** | Keeps valid words like `п'ять`, `об'єкт`, and hyphenated Cyrillic words from being incorrectly rejected |
| **Dictionary-aware correction** | Uses macOS spell checking to avoid changing words that are already valid |
| **Shell command protection** | Avoids "fixing" common terminal commands that should stay in English |
| **Automatic input-source switching** | Switches the active keyboard layout after a successful correction when possible |
| **Menu bar controls** | Lets you pause/resume corrections, open setup, change preferences, and inspect the current shortcut |

## How It Works

LangSwitcher installs a global `CGEventTap` at the session level.

When you type:

1. The app buffers the current word.
2. On `Space` or `Return`, it first checks custom text shortcuts.
3. If no text shortcut matches, it tries to detect a layout mistake.
4. It converts the word only when the result looks valid according to macOS dictionaries or known shell-command rules.
5. After a successful correction, it can switch the active input source to match the corrected script.

Supported correction directions:

- **Cyrillic → English**
- **English → Cyrillic**
- **Mixed-script Cyrillic validation with Latin lookalikes**

Current Cyrillic support is centered on Russian and Ukrainian keyboard layouts, including Ukrainian-specific letters such as `ґ`, `і`, `ї`, and `є`.

## Installation

### Option 1: Use the DMG

If you already have a built disk image:

1. Open `LangSwitcher.dmg`
2. Drag `LangSwitcher.app` into `Applications`
3. Launch the app
4. Complete the setup assistant and grant Accessibility access

### Option 2: Build from Source

Requirements:

- macOS 13 or later
- Xcode with Swift 6 support, or a recent Swift 6 toolchain

Build with SwiftPM:

```bash
swift build
```

Run directly:

```bash
swift run LangSwitcher
```

Open in Xcode:

```bash
open LangSwitcher.xcodeproj
```

Build a Release app bundle with Xcode:

```bash
xcodebuild -project LangSwitcher.xcodeproj -scheme LangSwitcher -configuration Release CODE_SIGNING_ALLOWED=NO build
```

## Testing

Unit tests are included for the Cyrillic mapping and normalization logic.

Run them with:

```bash
swift test
```

The current test suite covers regressions around:

- lowercase Latin lookalikes inside Cyrillic words
- apostrophes in valid Cyrillic words
- hyphenated Cyrillic words
- unsupported-character rejection during normalization

## Settings and Data

LangSwitcher stores user preferences in macOS `UserDefaults` under the bundle identifier:

```text
com.tetrex.langSwitcher
```

That includes:

- the force-convert shortcut
- custom text shortcuts

On disk, this usually appears at:

```text
~/Library/Preferences/com.tetrex.langSwitcher.plist
```

## Project Structure

```text
Sources/LangSwitcher/
  LangSwitcher.swift
  MenuBarController.swift
  KeyboardInterceptor.swift
  CyrillicMapper.swift
  SettingsWindowController.swift
  WelcomeWindowController.swift
  AboutWindowController.swift
  ShortcutConfiguration.swift
  ShortcutRecorder.swift
  TextShortcutsStore.swift

Tests/LangSwitcherTests/
  CyrillicMapperTests.swift
```

## Notes

- LangSwitcher is a menu bar app, so it does not appear in the Dock during normal use.
- The app depends on Accessibility permission; without it, correction cannot work.
- Local preferences are not baked into the compiled app bundle or DMG. They stay on the machine where the app runs.
