# Repository Guidelines

## Project Structure & Module Organization
LangSwitcher is a macOS Swift executable app.

- `Sources/LangSwitcher/`: main app code (`LangSwitcher.swift`, controllers, keyboard interception, mapping logic, shortcut persistence/recording).
- `Sources/LangSwitcher/Assets.xcassets/`: app image assets.
- `Sources/LangSwitcher/AppIcon.icon/`: icon bundle copied at build time.
- `Tests/LangSwitcherTests/`: unit tests for mapping and regression coverage.
- `LangSwitcher.xcodeproj/`: Xcode project and shared scheme.
- `Package.swift`: Swift Package Manager target and linker settings.

Keep feature code grouped by responsibility (event interception, mapping/conversion, UI/window controllers, shortcut recording, persistence).

## Build, Test, and Development Commands
- `swift build`  
  Builds the executable target declared in `Package.swift`.
- `swift run LangSwitcher`  
  Runs the app from SwiftPM (useful for quick local iteration).
- `swift test`  
  Runs the committed unit test target in `Tests/LangSwitcherTests`.
- `swift package resolve`  
  Refreshes package dependencies and lock state.
- `open LangSwitcher.xcodeproj`  
  Opens the project in Xcode for signing, debugging, and app bundle workflows.
- `xcodebuild -project LangSwitcher.xcodeproj -scheme LangSwitcher -configuration Release CODE_SIGNING_ALLOWED=NO build`  
  Produces an unsigned Release app bundle for local packaging/testing.

If you change logic in the mapper, interceptor, or shortcut persistence flow, run `swift test`.

## Coding Style & Naming Conventions
- Language: Swift 6+ style, 4-space indentation, no tabs.
- Types: `UpperCamelCase` (`KeyboardInterceptor`).
- Methods/properties/variables: `lowerCamelCase` (`convertWord`, `textShortcutsStore`).
- Prefer small, focused types and explicit access control.
- Keep UI/window controller behavior in `*WindowController.swift`; keep text conversion logic in mapper/interceptor files.

No formatter/linter is currently enforced in-repo. Match existing style and keep diffs minimal.

## Testing Guidelines
There is a committed SwiftPM test target under `Tests/LangSwitcherTests`. Extend it when adding non-trivial logic, especially around mapping, correction rules, shortcut recording/persistence, or shortcut expansion.

Minimum expectation for logic changes:
- cover normal conversions,
- cover edge cases (mixed scripts, punctuation, empty input),
- cover regressions from reported bugs.

Prefer keeping mapper/regression tests in files like `CyrillicMapperTests.swift`, and add focused new test files only when a different component needs isolated coverage.

## Commit & Pull Request Guidelines
Recent history shows short, imperative commit messages (for example, `Update README.md`, `Remove ... support`). Follow that style, but be specific.

- Commit format: imperative verb + scope (`Refactor KeyboardInterceptor word boundary handling`).
- Avoid vague messages like `bug fixes`.
- One logical change per commit when possible.

PRs should include:
- what changed and why,
- user-visible impact (especially keyboard behavior),
- manual verification steps,
- screenshots/video for UI or settings window changes.

## Security & Configuration Notes
LangSwitcher requires macOS Accessibility permission to intercept keystrokes. Do not commit private signing assets, certificates, or developer-specific local paths.

User shortcut preferences and text expansions are stored locally in macOS `UserDefaults` under `com.tetrex.langSwitcher`; they are not baked into the compiled app bundle or DMG.
