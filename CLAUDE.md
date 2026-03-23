# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

The app has both an Xcode project (`LangSwitcher.xcodeproj`) and a Swift Package (`Package.swift`). Use whichever suits the task; Xcode is preferred for signing/distribution.

**Swift Package (CLI):**
```bash
swift build                          # debug build
swift build -c release               # release build
swift run                            # build + run (requires Accessibility permission)
```

**Xcode:**
Open `LangSwitcher.xcodeproj` and use the standard Build/Run commands (⌘B / ⌘R).

There are no automated tests in this project.

## Architecture

**Entry point:** `LangSwitcher.swift` — `@main` struct, sets activation policy to `.accessory` (no Dock icon), creates `AppDelegate` which owns `MenuBarController`.

**Object graph (all `@MainActor`):**
```
AppDelegate
  └─ MenuBarController       — NSStatusItem + NSMenu, owns the other controllers
       ├─ KeyboardInterceptor — CGEventTap, word buffer, layout switching
       ├─ SettingsWindowController  (lazy, nil when closed)
       └─ WelcomeWindowController   (lazy, nil when closed)
```

**`KeyboardInterceptor`** is the core. It:
- Creates a `CGEvent.tapCreate` at `.cgSessionEventTap` with `.headInsertEventTap`
- Buffers typed characters into `currentWord`; clears on Escape/arrows/non-char keys
- On Space/Enter: checks the buffered word against `CyrillicMapper` spell-check logic and replaces it if mistyped; suppresses the original event (`return nil`) and replays it synthetically
- On force-convert shortcut: supports modifier-based (single press) or double-tap mode; configured via `forceConvertKeyCode` / `forceConvertModifiers`
- Replacement is done by posting synthetic Backspace × N events then a Unicode string event; the tap is temporarily disabled during replay to avoid re-entry
- Layout switching uses `TISCreateInputSourceList` / `TISSelectInputSource` from `Carbon.HIToolbox`

**`CyrillicMapper`** (pure static enum, no side effects):
- `cyrillicToEn`: direct Cyrillic→QWERTY character map (Russian ЙЦУКЕН + Ukrainian extras)
- `enToCyrillicVariants`: QWERTY→Cyrillic, with `s`/`S` mapping to both `ы`/`і` for Ru/Uk ambiguity; `buildCyrillicCandidates` does a BFS expansion (capped at 64 candidates)
- `isValidCyrillicWord` / `isValidEnglishWord`: delegates to `NSSpellChecker.shared`
- `isValidCyrillicWordConsideringLatinOverlap`: normalizes visually-similar Latin letters (A/А, C/С, etc.) to Cyrillic before spell-checking

**`TextShortcutsStore`** (`@MainActor` singleton): stores user-defined text expansion shortcuts (e.g. `"mymail"` → `"user@example.com"`). Persisted in `UserDefaults` as JSON under key `"TextShortcuts"`. `KeyboardInterceptor` calls `expansion(for:)` on word completion to check for a match before the Cyrillic correction logic.

**`SettingsWindowController`** / **`WelcomeWindowController`**: programmatic AppKit UIs (no NIBs/Storyboards). Shortcut is persisted in `UserDefaults` under keys `ForceConvertKeyCode` / `ForceConvertModifiers`. Default shortcut: ⌥T (`kVK_ANSI_T` + `maskAlternate`).

## Key Design Constraints

- The `CGEventTapCallBack` is a C function pointer — `self` cannot be captured directly. It is passed via the `userInfo` opaque pointer using `Unmanaged.passUnretained`.
- The event tap must be temporarily disabled (`CGEvent.tapEnable(tap:enable:false)`) before posting synthetic events to avoid recursive re-entry into `handleKeyDown`.
- All UI and event-tap work is `@MainActor`. The C callback uses `MainActor.assumeIsolated` where needed.
- Swift 6 strict concurrency is in use (swift-tools-version 6.2).
