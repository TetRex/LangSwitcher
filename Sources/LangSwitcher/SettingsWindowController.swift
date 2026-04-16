import AppKit

/// A settings window that lets the user configure the force-convert shortcut
/// and manage custom text expansion shortcuts.
@MainActor
final class SettingsWindowController: NSWindowController {

    private let shortcutContainer = NSView()
    private let shortcutField = NSTextField(labelWithString: "")
    private let recordShortcutButton = NSButton()
    private let instructionLabel = NSTextField(labelWithString: "")
    private let modeLabel = NSTextField(labelWithString: "")
    private let validationLabel = NSTextField(labelWithString: "")
    private let shortcutRecorder = ShortcutRecorder()

    /// Called when the user picks a new shortcut.
    var onShortcutChanged: ((_ keyCode: Int, _ modifiers: UInt64) -> Void)?

    private let shortcutsTableView = NSTableView()
    private let shortcutsScrollView = NSScrollView()
    private let addButton = NSButton()
    private let removeButton = NSButton()

    private var currentKeyCode: Int
    private var currentModifiers: UInt64

    init(currentKeyCode: Int, currentModifiers: UInt64) {
        self.currentKeyCode = currentKeyCode
        self.currentModifiers = currentModifiers

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "LangSwitcher Preferences"
        window.toolbarStyle = .preference
        window.center()
        window.isReleasedWhenClosed = false
        window.backgroundColor = .windowBackgroundColor

        super.init(window: window)
        buildUI()
        updateShortcutDisplay()
        updateValidationUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - UI Construction

    private static func makeSectionHeader(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .labelColor
        return label
    }

    private static func makeSecondaryLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        let backgroundView = NSVisualEffectView()
        backgroundView.material = .windowBackground
        backgroundView.blendingMode = .behindWindow
        backgroundView.state = .active
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(backgroundView)

        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 18
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(contentStack)

        let titleLabel = NSTextField(labelWithString: "Preferences")
        titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        titleLabel.textColor = .labelColor

        let subtitleLabel = Self.makeSecondaryLabel(
            "Adjust your force-convert shortcut and manage the text expansions LangSwitcher should type for you."
        )

        let headerStack = NSStackView(views: [titleLabel, subtitleLabel])
        headerStack.orientation = .vertical
        headerStack.alignment = .leading
        headerStack.spacing = 4
        contentStack.addArrangedSubview(headerStack)

        contentStack.addArrangedSubview(makeShortcutCard())
        contentStack.addArrangedSubview(makeTextShortcutsCard())

        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: contentView.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            contentStack.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -24),
            contentStack.topAnchor.constraint(equalTo: backgroundView.topAnchor, constant: 24),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: backgroundView.bottomAnchor, constant: -24),
        ])
    }

    private func makeShortcutCard() -> NSView {
        let card = makeCardView()

        let header = Self.makeSectionHeader("Force Convert Shortcut")
        let description = Self.makeSecondaryLabel(
            "Click the shortcut button, then press the key combination you want to use while typing."
        )

        shortcutContainer.wantsLayer = true
        shortcutContainer.layer?.cornerRadius = 10
        shortcutContainer.layer?.borderWidth = 1
        shortcutContainer.layer?.borderColor = NSColor.separatorColor.cgColor
        shortcutContainer.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        shortcutContainer.translatesAutoresizingMaskIntoConstraints = false
        shortcutContainer.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(startRecording)))

        shortcutField.font = .monospacedSystemFont(ofSize: 15, weight: .medium)
        shortcutField.textColor = .labelColor
        shortcutField.alignment = .center
        shortcutField.lineBreakMode = .byTruncatingTail
        shortcutField.translatesAutoresizingMaskIntoConstraints = false
        shortcutContainer.addSubview(shortcutField)

        configureButton(recordShortcutButton, title: "Record Shortcut", symbol: "pencil.line")
        recordShortcutButton.action = #selector(startRecording)

        let controlsRow = NSStackView(views: [shortcutContainer, recordShortcutButton])
        controlsRow.orientation = .horizontal
        controlsRow.alignment = .centerY
        controlsRow.spacing = 10

        instructionLabel.font = .systemFont(ofSize: 12)
        instructionLabel.textColor = .secondaryLabelColor
        instructionLabel.maximumNumberOfLines = 0
        instructionLabel.lineBreakMode = .byWordWrapping

        modeLabel.font = .systemFont(ofSize: 12, weight: .medium)
        modeLabel.textColor = .tertiaryLabelColor

        let stack = NSStackView(views: [header, description, controlsRow, instructionLabel, modeLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            shortcutContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),
            shortcutContainer.heightAnchor.constraint(equalToConstant: 38),
            shortcutField.leadingAnchor.constraint(equalTo: shortcutContainer.leadingAnchor, constant: 10),
            shortcutField.trailingAnchor.constraint(equalTo: shortcutContainer.trailingAnchor, constant: -10),
            shortcutField.centerYAnchor.constraint(equalTo: shortcutContainer.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])

        return card
    }

    private func makeTextShortcutsCard() -> NSView {
        let card = makeCardView()

        let header = Self.makeSectionHeader("Text Shortcuts")
        let description = Self.makeSecondaryLabel(
            "Triggers are matched exactly as typed. Invalid entries are highlighted while you edit them."
        )

        configureShortcutButtons()
        let actionsStack = NSStackView(views: [addButton, removeButton])
        actionsStack.orientation = .horizontal
        actionsStack.spacing = 8

        let headerRow = NSStackView(views: [header, NSView(), actionsStack])
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 8

        configureTableView()

        validationLabel.font = .systemFont(ofSize: 12, weight: .medium)
        validationLabel.textColor = .secondaryLabelColor
        validationLabel.maximumNumberOfLines = 0
        validationLabel.lineBreakMode = .byWordWrapping

        let stack = NSStackView(views: [headerRow, description, shortcutsScrollView, validationLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            shortcutsScrollView.heightAnchor.constraint(equalToConstant: 220),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])

        return card
    }

    private func makeCardView() -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.layer?.cornerRadius = 14
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.separatorColor.cgColor
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.88).cgColor
        return card
    }

    private func configureShortcutButtons() {
        configureButton(addButton, title: "Add Shortcut", symbol: "plus")
        addButton.action = #selector(addShortcut)

        configureButton(removeButton, title: "Remove", symbol: "minus")
        removeButton.action = #selector(removeShortcut)
        removeButton.isEnabled = false
    }

    private func configureButton(_ button: NSButton, title: String, symbol: String) {
        button.title = title
        button.target = self
        button.bezelStyle = .rounded
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        button.imagePosition = .imageLeading
        button.contentTintColor = .controlAccentColor
    }

    private func configureTableView() {
        let triggerColumn = NSTableColumn(identifier: .init("trigger"))
        triggerColumn.title = "Trigger"
        triggerColumn.width = 150
        triggerColumn.minWidth = 90

        let expansionColumn = NSTableColumn(identifier: .init("expansion"))
        expansionColumn.title = "Expands To"
        expansionColumn.minWidth = 220

        shortcutsTableView.addTableColumn(triggerColumn)
        shortcutsTableView.addTableColumn(expansionColumn)
        shortcutsTableView.delegate = self
        shortcutsTableView.dataSource = self
        shortcutsTableView.rowHeight = 30
        shortcutsTableView.gridStyleMask = .solidHorizontalGridLineMask
        shortcutsTableView.gridColor = .separatorColor
        shortcutsTableView.backgroundColor = .textBackgroundColor
        shortcutsTableView.selectionHighlightStyle = .regular
        shortcutsTableView.usesAlternatingRowBackgroundColors = true
        shortcutsTableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle

        shortcutsScrollView.documentView = shortcutsTableView
        shortcutsScrollView.hasVerticalScroller = true
        shortcutsScrollView.borderType = .bezelBorder
        shortcutsScrollView.drawsBackground = true
        shortcutsScrollView.backgroundColor = .textBackgroundColor
        shortcutsScrollView.translatesAutoresizingMaskIntoConstraints = false
    }

    // MARK: - Shortcut UI

    private func updateShortcutDisplay() {
        let displayName = ShortcutConfiguration.displayName(keyCode: currentKeyCode, modifiers: currentModifiers)
        shortcutField.stringValue = shortcutRecorder.isRecording ? "Recording…" : displayName
        shortcutField.textColor = shortcutRecorder.isRecording ? .systemRed : .labelColor
        shortcutContainer.layer?.borderColor = (shortcutRecorder.isRecording ? NSColor.systemRed : NSColor.separatorColor).cgColor
        recordShortcutButton.contentTintColor = shortcutRecorder.isRecording ? .systemRed : .controlAccentColor
        instructionLabel.stringValue = shortcutRecorder.isRecording
            ? "Press Escape to cancel, or press the new shortcut now."
            : "Click the field or choose “Record Shortcut” to change it. Current shortcut: \(displayName)"

        let hasModifiers = ShortcutConfiguration.significantModifiers(currentModifiers) != 0
        modeLabel.stringValue = hasModifiers
            ? "Single press mode"
            : "Double-tap mode"
    }

    @objc private func startRecording() {
        updateShortcutDisplay()
        shortcutField.stringValue = "Recording…"
        shortcutField.textColor = .systemRed
        shortcutContainer.layer?.borderColor = NSColor.systemRed.cgColor
        recordShortcutButton.contentTintColor = .systemRed
        instructionLabel.stringValue = "Press Escape to cancel, or press the new shortcut now."

        shortcutRecorder.start { [weak self] in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.updateShortcutDisplay()
            }
        } onShortcut: { [weak self] keyCode, modifiers in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.currentKeyCode = keyCode
                self.currentModifiers = modifiers
                ShortcutConfiguration.save(keyCode: keyCode, modifiers: modifiers)
                self.updateShortcutDisplay()
                self.onShortcutChanged?(keyCode, modifiers)
            }
        }
    }

    func stopShortcutRecording() {
        shortcutRecorder.stop()
        updateShortcutDisplay()
    }

    // MARK: - Text Shortcut Actions

    @objc private func addShortcut() {
        let store = TextShortcutsStore.shared
        store.add()
        let newRow = store.shortcuts.count - 1
        shortcutsTableView.reloadData()
        shortcutsTableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
        updateValidationUI()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let cell = self.shortcutsTableView.view(atColumn: 0, row: newRow, makeIfNecessary: false) as? NSTableCellView {
                self.shortcutsTableView.window?.makeFirstResponder(cell.textField)
            }
        }
    }

    @objc private func removeShortcut() {
        let row = activeShortcutRow()
        guard row >= 0 else { return }
        TextShortcutsStore.shared.remove(at: row)
        shortcutsTableView.reloadData()
        let nextRow = min(row, TextShortcutsStore.shared.shortcuts.count - 1)
        if nextRow >= 0 {
            shortcutsTableView.selectRowIndexes(IndexSet(integer: nextRow), byExtendingSelection: false)
        }
        updateValidationUI()
    }

    // MARK: - Validation

    private enum ShortcutIssue: String {
        case empty = "Trigger cannot be empty."
        case whitespace = "Trigger cannot contain only whitespace."
        case duplicate = "Another shortcut already uses this trigger."
    }

    private func issue(forRow row: Int) -> ShortcutIssue? {
        let shortcuts = TextShortcutsStore.shared.shortcuts
        guard shortcuts.indices.contains(row) else { return nil }

        let trigger = shortcuts[row].trigger
        if trigger.isEmpty { return .empty }

        let trimmed = trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .whitespace }

        for (index, shortcut) in shortcuts.enumerated() where index != row {
            if shortcut.trigger.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed {
                return .duplicate
            }
        }

        return nil
    }

    private func updateValidationUI() {
        let selectedRow = activeShortcutRow()
        removeButton.isEnabled = selectedRow >= 0

        if selectedRow >= 0, let issue = issue(forRow: selectedRow) {
            validationLabel.stringValue = issue.rawValue
            validationLabel.textColor = .systemRed
        } else {
            let invalidRows = TextShortcutsStore.shared.shortcuts.indices.filter { issue(forRow: $0) != nil }
            if invalidRows.isEmpty {
                validationLabel.stringValue = "Triggers are matched exactly as typed, so short memorable words work best."
                validationLabel.textColor = .secondaryLabelColor
            } else {
                validationLabel.stringValue = "\(invalidRows.count) shortcut issue\(invalidRows.count == 1 ? "" : "s") still need attention."
                validationLabel.textColor = .systemOrange
            }
        }

        refreshVisibleCellStyles()
    }

    private func styleTextField(_ textField: NSTextField, row: Int, isTrigger: Bool) {
        textField.font = isTrigger
            ? .monospacedSystemFont(ofSize: 13, weight: .medium)
            : .systemFont(ofSize: 13)

        if isTrigger, let issue = issue(forRow: row) {
            textField.textColor = .systemRed
            textField.toolTip = issue.rawValue
        } else {
            textField.textColor = .labelColor
            textField.toolTip = nil
        }
    }

    private func updateShortcut(at row: Int, trigger: String? = nil, expansion: String? = nil) {
        let store = TextShortcutsStore.shared
        guard store.shortcuts.indices.contains(row) else { return }

        let current = store.shortcuts[row]
        store.update(at: row,
                     trigger: trigger ?? current.trigger,
                     expansion: expansion ?? current.expansion)
    }

    private func activeShortcutRow() -> Int {
        if shortcutsTableView.selectedRow >= 0 {
            return shortcutsTableView.selectedRow
        }
        if shortcutsTableView.editedRow >= 0 {
            return shortcutsTableView.editedRow
        }
        return -1
    }

    private func refreshVisibleCellStyles() {
        let rowRange = shortcutsTableView.rows(in: shortcutsTableView.visibleRect)
        guard rowRange.length > 0 else { return }

        let endRow = rowRange.location + rowRange.length
        for row in rowRange.location..<endRow {
            for (column, isTrigger) in [(0, true), (1, false)] {
                guard let cell = shortcutsTableView.view(atColumn: column, row: row, makeIfNecessary: false) as? NSTableCellView,
                      let textField = cell.textField else { continue }
                styleTextField(textField, row: row, isTrigger: isTrigger)
                cell.toolTip = textField.toolTip
            }
        }
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
        let identifier = NSUserInterfaceItemIdentifier(isTrigger ? "TriggerCell" : "ExpansionCell")

        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
            ?? makeShortcutCell(identifier: identifier, columnTag: isTrigger ? 0 : 1)

        let shortcuts = TextShortcutsStore.shared.shortcuts
        guard shortcuts.indices.contains(row), let textField = cell.textField else { return cell }

        textField.stringValue = isTrigger ? shortcuts[row].trigger : shortcuts[row].expansion
        styleTextField(textField, row: row, isTrigger: isTrigger)
        cell.toolTip = textField.toolTip
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateValidationUI()
    }

    private func makeShortcutCell(identifier: NSUserInterfaceItemIdentifier,
                                  columnTag: Int) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier

        let textField = NSTextField()
        textField.isEditable = true
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.delegate = self
        textField.tag = columnTag
        textField.translatesAutoresizingMaskIntoConstraints = false

        cell.addSubview(textField)
        cell.textField = textField

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])

        return cell
    }
}

// MARK: - NSTextFieldDelegate

extension SettingsWindowController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField,
              let cellView = textField.superview else { return }

        let row = shortcutsTableView.row(for: cellView)
        guard row >= 0 else { return }

        if textField.tag == 0 {
            updateShortcut(at: row, trigger: textField.stringValue)
            styleTextField(textField, row: row, isTrigger: true)
        } else {
            updateShortcut(at: row, expansion: textField.stringValue)
        }

        updateValidationUI()
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        shortcutsTableView.reloadData()
        updateValidationUI()
    }
}
