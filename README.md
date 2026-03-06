# LangSwitcher

A lightweight macOS menu bar utility that automatically converts Cyrillic text typed on an English QWERTY keyboard back to English.

## How It Works

LangSwitcher runs silently in the menu bar and intercepts keyboard input via a global event tap. When you accidentally type a word in Cyrillic while your keyboard layout is set to Russian, it detects the mistake and converts the characters to their QWERTY equivalents on Space or Enter.

The app uses the macOS spell checker to verify whether the typed word is actually valid Russian — this avoids false positives and ensures only mistyped words are corrected.

## Features

- **Real-time keystroke interception** — converts Cyrillic input on the fly
- **Smart detection** — validates words against the macOS spell checker before converting
- **Full ЙЦУКЕН → QWERTY mapping** — all lowercase and uppercase characters
- **Menu bar app** — no Dock icon, just a small keyboard icon in the status bar
- **Toggle on/off** — enable or disable from the menu
- **Universal binary** — Apple Silicon + Intel

> On first launch macOS may show a Gatekeeper warning. Right-click the app → **Open** to bypass it.

  
