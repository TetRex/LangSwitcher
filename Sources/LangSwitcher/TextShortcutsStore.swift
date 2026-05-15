import Foundation

struct TextShortcut: Codable {
    var trigger: String
    var expansion: String
}

/// Stores user-defined text shortcuts (e.g. "mymail" → "user@example.com").
/// Persisted in UserDefaults as JSON.
@MainActor
final class TextShortcutsStore {

    static let shared = TextShortcutsStore()

    private static let defaultsKey = "TextShortcuts"

    private var expansionsByTrigger: [String: String] = [:]

    private(set) var shortcuts: [TextShortcut] = [] {
        didSet { rebuildLookup() }
    }

    private init() { load() }

    // MARK: - Lookup

    func expansion(for trigger: String) -> String? {
        expansionsByTrigger[trigger]
    }

    // MARK: - Mutation

    func add(trigger: String = "", expansion: String = "") {
        shortcuts.append(TextShortcut(trigger: trigger, expansion: expansion))
        save()
    }

    func remove(at index: Int) {
        guard shortcuts.indices.contains(index) else { return }
        shortcuts.remove(at: index)
        save()
    }

    func update(at index: Int, trigger: String, expansion: String) {
        guard shortcuts.indices.contains(index) else { return }
        shortcuts[index].trigger = trigger
        shortcuts[index].expansion = expansion
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
              let decoded = try? JSONDecoder().decode([TextShortcut].self, from: data) else { return }
        shortcuts = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(shortcuts) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }

    private func rebuildLookup() {
        var lookup: [String: String] = [:]
        lookup.reserveCapacity(shortcuts.count)

        // Match the previous linear scan behavior: the first shortcut wins.
        for shortcut in shortcuts.reversed() {
            lookup[shortcut.trigger] = shortcut.expansion
        }

        expansionsByTrigger = lookup
    }
}
