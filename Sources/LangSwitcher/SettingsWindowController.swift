import AppKit
import Carbon.HIToolbox

/// A settings window that lets the user configure the force‑convert shortcut
/// and manage custom text expansion shortcuts.
@MainActor
final class SettingsWindowController: NSWindowController {

    // MARK: - UI — force-convert shortcut

    private let shortcutField = NSTextField()
    private let instructionLabel = NSTextField(labelWithString: "")
    private let modeLabel = NSTextField(labelWithString: "")
    private let shortcutRecorder = ShortcutRecorder()

    /// Called when the user picks a new shortcut.
    var onShortcutChanged: ((_ keyCode: Int, _ modifiers: UInt64) -> Void)?

    // MARK: - UI — text shortcuts table

    private let shortcutsTableView = NSTableView()
    private let shortcutsScrollView = NSScrollView()
    private var addButton: NSButton!
    private var removeButton: NSButton!

    // MARK: - Current shortcut value

    private var currentKeyCode: Int
    private var currentModifiers: UInt64   // raw CGEventFlags bits for ⌘⌥⌃⇧

    // MARK: - Init

    init(currentKeyCode: Int, currentModifiers: UInt64) {
        self.currentKeyCode = currentKeyCode
        self.currentModifiers = currentModifiers

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "LangSwitcher Prefernces"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = .black
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
        buildUI()
        updateFieldDisplay()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - UI construction

    // Convenience: small uppercase gray section header
    private static func makeSectionHeader(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text.uppercased())
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = NSColor(white: 0.45, alpha: 1)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.black.cgColor

        // App title at the top
        let appTitle = NSTextField(labelWithString: "Preferences")
        appTitle.font = .systemFont(ofSize: 15, weight: .semibold)
        appTitle.textColor = .white
        appTitle.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(appTitle)

        // — Force-convert shortcut section —

        let shortcutHeader = Self.makeSectionHeader("Force‑Convert Shortcut")
        contentView.addSubview(shortcutHeader)

        // Container gives the dark rounded background; the field sits centered inside it.
        let shortcutContainer = NSView()
        shortcutContainer.wantsLayer = true
        shortcutContainer.layer?.backgroundColor = NSColor(white: 0.12, alpha: 1).cgColor
        shortcutContainer.layer?.cornerRadius = 8
        shortcutContainer.layer?.borderWidth = 1
        shortcutContainer.layer?.borderColor = NSColor(white: 0.28, alpha: 1).cgColor
        shortcutContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(shortcutContainer)

        shortcutField.isEditable = false
        shortcutField.isSelectable = false
        shortcutField.alignment = .center
        shortcutField.font = .monospacedSystemFont(ofSize: 15, weight: .medium)
        shortcutField.isBezeled = false
        shortcutField.drawsBackground = false
        shortcutField.textColor = .white
        shortcutField.translatesAutoresizingMaskIntoConstraints = false
        shortcutContainer.addSubview(shortcutField)

        NSLayoutConstraint.activate([
            shortcutField.centerYAnchor.constraint(equalTo: shortcutContainer.centerYAnchor),
            shortcutField.leadingAnchor.constraint(equalTo: shortcutContainer.leadingAnchor, constant: 8),
            shortcutField.trailingAnchor.constraint(equalTo: shortcutContainer.trailingAnchor, constant: -8),
        ])

        let click = NSClickGestureRecognizer(target: self, action: #selector(startRecording))
        shortcutContainer.addGestureRecognizer(click)

        instructionLabel.font = .systemFont(ofSize: 11)
        instructionLabel.textColor = NSColor(white: 0.45, alpha: 1)
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(instructionLabel)

        modeLabel.font = .systemFont(ofSize: 11)
        modeLabel.textColor = NSColor(white: 0.3, alpha: 1)
        modeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(modeLabel)

        // Thin dark separator
        let separatorView = NSView()
        separatorView.wantsLayer = true
        separatorView.layer?.backgroundColor = NSColor(white: 0.2, alpha: 1).cgColor
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(separatorView)

        // — Text shortcuts section —

        let textShortcutsHeader = Self.makeSectionHeader("Text Shortcuts")
        contentView.addSubview(textShortcutsHeader)

        let triggerCol = NSTableColumn(identifier: .init("trigger"))
        triggerCol.title = "Shortcut"
        triggerCol.width = 140
        triggerCol.minWidth = 60

        let expansionCol = NSTableColumn(identifier: .init("expansion"))
        expansionCol.title = "Expands To"
        expansionCol.minWidth = 120

        shortcutsTableView.addTableColumn(triggerCol)
        shortcutsTableView.addTableColumn(expansionCol)
        shortcutsTableView.delegate = self
        shortcutsTableView.dataSource = self
        shortcutsTableView.usesAlternatingRowBackgroundColors = false
        shortcutsTableView.backgroundColor = NSColor(white: 0.08, alpha: 1)
        shortcutsTableView.rowHeight = 26
        shortcutsTableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        shortcutsTableView.gridStyleMask = .solidHorizontalGridLineMask
        shortcutsTableView.gridColor = NSColor(white: 0.18, alpha: 1)

        shortcutsScrollView.documentView = shortcutsTableView
        shortcutsScrollView.hasVerticalScroller = true
        shortcutsScrollView.borderType = .noBorder
        shortcutsScrollView.drawsBackground = false
        shortcutsScrollView.wantsLayer = true
        shortcutsScrollView.layer?.cornerRadius = 8
        shortcutsScrollView.layer?.borderWidth = 1
        shortcutsScrollView.layer?.borderColor = NSColor(white: 0.22, alpha: 1).cgColor
        shortcutsScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(shortcutsScrollView)

        // Segmented +/− control
        let segmented = NSSegmentedControl()
        segmented.segmentCount = 2
        segmented.setImage(NSImage(systemSymbolName: "plus", accessibilityDescription: "Add")!, forSegment: 0)
        segmented.setImage(NSImage(systemSymbolName: "minus", accessibilityDescription: "Remove")!, forSegment: 1)
        segmented.segmentStyle = .smallSquare
        segmented.target = self
        segmented.action = #selector(segmentedAction(_:))
        segmented.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(segmented)

        // Keep references so +/− can be controlled
        addButton = NSButton(title: "+", target: self, action: #selector(addShortcut))
        addButton.isHidden = true
        removeButton = NSButton(title: "−", target: self, action: #selector(removeShortcut))
        removeButton.isHidden = true
        removeButton.isEnabled = false
        contentView.addSubview(addButton)
        contentView.addSubview(removeButton)

        NSLayoutConstraint.activate([
            // Center title in the transparent titlebar (≈28 pt tall)
            appTitle.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            appTitle.centerYAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),

            // Content starts below the titlebar safe area
            shortcutHeader.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 16),
            shortcutHeader.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),

            shortcutContainer.topAnchor.constraint(equalTo: shortcutHeader.bottomAnchor, constant: 8),
            shortcutContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),
            shortcutContainer.widthAnchor.constraint(equalToConstant: 180),
            shortcutContainer.heightAnchor.constraint(equalToConstant: 36),

            instructionLabel.topAnchor.constraint(equalTo: shortcutContainer.bottomAnchor, constant: 8),
            instructionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),
            instructionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -22),

            modeLabel.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 3),
            modeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),
            modeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -22),

            separatorView.topAnchor.constraint(equalTo: modeLabel.bottomAnchor, constant: 18),
            separatorView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),
            separatorView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -22),
            separatorView.heightAnchor.constraint(equalToConstant: 1),

            textShortcutsHeader.topAnchor.constraint(equalTo: separatorView.bottomAnchor, constant: 14),
            textShortcutsHeader.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),
            textShortcutsHeader.centerYAnchor.constraint(equalTo: segmented.centerYAnchor),

            segmented.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -22),
            segmented.topAnchor.constraint(equalTo: separatorView.bottomAnchor, constant: 10),

            shortcutsScrollView.topAnchor.constraint(equalTo: textShortcutsHeader.bottomAnchor, constant: 8),
            shortcutsScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),
            shortcutsScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -22),
            shortcutsScrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18),
        ])
    }

    @objc private func segmentedAction(_ sender: NSSegmentedControl) {
        if sender.selectedSegment == 0 {
            addShortcut()
        } else {
            removeShortcut()
        }
    }

    // MARK: - Shortcut field display

    private func updateFieldDisplay() {
        shortcutField.stringValue = ShortcutConfiguration.displayName(keyCode: currentKeyCode,
                                                                     modifiers: currentModifiers)
        instructionLabel.stringValue = "Click the field, then press your shortcut."

        let hasModifiers = ShortcutConfiguration.significantModifiers(currentModifiers) != 0
        modeLabel.stringValue = hasModifiers
            ? "Mode: single press"
            : "Mode: double‑tap"
    }

    // MARK: - Shortcut recording

    @objc private func startRecording() {
        shortcutField.stringValue = "Press shortcut…"
        instructionLabel.stringValue = "Press Escape to cancel. Hold modifiers + key."

        shortcutRecorder.start { [weak self] in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.updateFieldDisplay()
            }
        } onShortcut: { [weak self] keyCode, modifiers in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.currentKeyCode = keyCode
                self.currentModifiers = modifiers
                self.updateFieldDisplay()

                ShortcutConfiguration.save(keyCode: keyCode, modifiers: modifiers)
                self.onShortcutChanged?(keyCode, modifiers)
            }
        }
    }

    // MARK: - Text shortcuts actions

    @objc private func addShortcut() {
        let store = TextShortcutsStore.shared
        store.add()
        let newRow = store.shortcuts.count - 1
        shortcutsTableView.reloadData()
        shortcutsTableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
        // Begin editing the trigger cell after the table has rendered the new row.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let cell = self.shortcutsTableView.view(atColumn: 0, row: newRow, makeIfNecessary: false) as? NSTableCellView {
                self.shortcutsTableView.window?.makeFirstResponder(cell.textField)
            }
        }
    }

    @objc private func removeShortcut() {
        let row = shortcutsTableView.selectedRow
        guard row >= 0 else { return }
        TextShortcutsStore.shared.remove(at: row)
        shortcutsTableView.reloadData()
        removeButton.isEnabled = false
    }

    // MARK: - Persistence helpers

    static func savedKeyCode() -> Int {
        ShortcutConfiguration.savedKeyCode()
    }

    static func savedModifiers() -> UInt64 {
        ShortcutConfiguration.savedModifiers()
    }

    // MARK: - Modifier helpers

    /// Keeps only ⌘ ⌥ ⌃ ⇧ bits.
    static func significantModifiers(_ raw: UInt64) -> UInt64 {
        ShortcutConfiguration.significantModifiers(raw)
    }

    /// Human‑readable name like "⌥T" or "⌘⇧K" or "Tab (×2)".
    static func displayName(keyCode: Int, modifiers: UInt64) -> String {
        ShortcutConfiguration.displayName(keyCode: keyCode, modifiers: modifiers)
    }

    // MARK: - Key name mapping

    private static let keyNames: [Int: String] = [
        kVK_Tab: "Tab",
        kVK_Return: "Return",
        kVK_Space: "Space",
        kVK_Delete: "Delete",
        kVK_ForwardDelete: "Fwd Delete",
        kVK_Escape: "Escape",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4",
        kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8",
        kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_CapsLock: "Caps Lock",
        kVK_LeftArrow: "←", kVK_RightArrow: "→",
        kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "Home", kVK_End: "End",
        kVK_PageUp: "Page Up", kVK_PageDown: "Page Down",
        kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C",
        kVK_ANSI_D: "D", kVK_ANSI_E: "E", kVK_ANSI_F: "F",
        kVK_ANSI_G: "G", kVK_ANSI_H: "H", kVK_ANSI_I: "I",
        kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
        kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O",
        kVK_ANSI_P: "P", kVK_ANSI_Q: "Q", kVK_ANSI_R: "R",
        kVK_ANSI_S: "S", kVK_ANSI_T: "T", kVK_ANSI_U: "U",
        kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
        kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
        kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2",
        kVK_ANSI_3: "3", kVK_ANSI_4: "4", kVK_ANSI_5: "5",
        kVK_ANSI_6: "6", kVK_ANSI_7: "7", kVK_ANSI_8: "8",
        kVK_ANSI_9: "9",
        kVK_ANSI_Grave: "`",
        kVK_ANSI_Minus: "-", kVK_ANSI_Equal: "=",
        kVK_ANSI_LeftBracket: "[", kVK_ANSI_RightBracket: "]",
        kVK_ANSI_Semicolon: ";", kVK_ANSI_Quote: "'",
        kVK_ANSI_Backslash: "\\", kVK_ANSI_Comma: ",",
        kVK_ANSI_Period: ".", kVK_ANSI_Slash: "/",
    ]

    static func nameForKeyCode(_ keyCode: Int) -> String {
        keyNames[keyCode] ?? "Key \(keyCode)"
    }
}

// MARK: - NSTableViewDataSource

extension SettingsWindowController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        TextShortcutsStore.shared.shortcuts.count
    }
}

// MARK: - NSTableViewDelegate

extension SettingsWindowController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView,
                   viewFor tableColumn: NSTableColumn?,
                   row: Int) -> NSView? {
        let isTrigger = tableColumn?.identifier.rawValue == "trigger"
        let cellID = NSUserInterfaceItemIdentifier(isTrigger ? "TriggerCell" : "ExpansionCell")

        let cell = tableView.makeView(withIdentifier: cellID, owner: self) as? NSTableCellView
                   ?? makeShortcutCell(identifier: cellID, columnTag: isTrigger ? 0 : 1)

        let shortcuts = TextShortcutsStore.shared.shortcuts
        guard shortcuts.indices.contains(row) else { return cell }
        cell.textField?.stringValue = isTrigger ? shortcuts[row].trigger : shortcuts[row].expansion
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        removeButton.isEnabled = shortcutsTableView.selectedRow >= 0
        // The segmented control doesn't disable individual segments automatically,
        // so we keep removeButton.isEnabled in sync for the action handler.
    }

    // MARK: - Cell factory

    private func makeShortcutCell(identifier: NSUserInterfaceItemIdentifier,
                                   columnTag: Int) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier

        let tf = NSTextField()
        tf.isEditable = true
        tf.isBezeled = false
        tf.drawsBackground = false
        tf.font = .systemFont(ofSize: 13)
        tf.textColor = .white
        tf.delegate = self
        tf.tag = columnTag   // 0 = trigger column, 1 = expansion column
        tf.translatesAutoresizingMaskIntoConstraints = false

        cell.addSubview(tf)
        cell.textField = tf

        NSLayoutConstraint.activate([
            tf.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            tf.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])

        return cell
    }
}

// MARK: - NSTextFieldDelegate (inline cell editing)

extension SettingsWindowController: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let tf = obj.object as? NSTextField,
              let cellView = tf.superview else { return }

        let row = shortcutsTableView.row(for: cellView)
        guard row >= 0 else { return }

        let store = TextShortcutsStore.shared
        guard store.shortcuts.indices.contains(row) else { return }

        let current = store.shortcuts[row]
        if tf.tag == 0 {
            store.update(at: row, trigger: tf.stringValue, expansion: current.expansion)
        } else {
            store.update(at: row, trigger: current.trigger, expansion: tf.stringValue)
        }
    }
}
