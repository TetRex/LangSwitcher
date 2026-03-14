<p align="center">
  <img src=".github/assets/appicon.png" alt="LangSwitcher logo" width="120">
</p>

<h1 align="center">LangSwitcher</h1>

<p align="center">
  A lightweight macOS menu bar app that automatically fixes keyboard layout mistakes between English and Cyrillic.
</p>

---

## Features

| | |
|---|---|
| **Auto-Convert** | Detects mistyped words and silently fixes the layout when you press Space or Enter |
| **Force Convert** | Press your shortcut mid-word to instantly switch the current word's layout |
| **Text Shortcuts** | Define trigger words that expand into full phrases automatically |
| **Bidirectional** | Handles both Cyrillic → English and English → Cyrillic corrections |
| **Smart Validation** | Uses macOS spell-check dictionaries to avoid false positives |
| **Layout Switch** | Automatically switches the active keyboard layout after each correction |
| **Ukrainian Support** | Full ЙЦУКЕН + Ukrainian extras — `ґ`, `і`, `ї`, `є` |

## How It Works

LangSwitcher intercepts keyboard input via a global event tap. As you type, it buffers the current word and on Space or Enter checks it against macOS dictionaries:

- **Cyrillic → English** — typed in the wrong layout, Cyrillic characters are mapped back to their QWERTY equivalents
- **English → Cyrillic** — typed in the wrong layout, QWERTY characters are mapped to the corresponding Cyrillic word

Only genuine mistakes are corrected — valid words in the current script are left untouched. After a correction, the active keyboard layout automatically switches to match.

## Requirements

- macOS 13 Ventura or later
- Accessibility permission (prompted on first launch)
