import AppKit

/// Maps Cyrillic characters typed on an English QWERTY keyboard
/// back to the corresponding English characters.
/// Supports Russian (ЙЦУКЕН) and Ukrainian keyboard layouts.
enum CyrillicMapper {

    // MARK: - Cyrillic → EN mapping (ЙЦУКЕН / Ukrainian → QWERTY)

    private static let cyrillicToEn: [Character: Character] = [
        // Russian lowercase (ЙЦУКЕН)
        "й": "q", "ц": "w", "у": "e", "к": "r", "е": "t",
        "н": "y", "г": "u", "ш": "i", "щ": "o", "з": "p",
        "х": "[", "ъ": "]",
        "ф": "a", "ы": "s", "в": "d", "а": "f", "п": "g",
        "р": "h", "о": "j", "л": "k", "д": "l", "ж": ";",
        "э": "'",
        "я": "z", "ч": "x", "с": "c", "м": "v", "и": "b",
        "т": "n", "ь": "m", "б": ",", "ю": ".",
        "ё": "`",
        // Russian uppercase
        "Й": "Q", "Ц": "W", "У": "E", "К": "R", "Е": "T",
        "Н": "Y", "Г": "U", "Ш": "I", "Щ": "O", "З": "P",
        "Х": "{", "Ъ": "}",
        "Ф": "A", "Ы": "S", "В": "D", "А": "F", "П": "G",
        "Р": "H", "О": "J", "Л": "K", "Д": "L", "Ж": ":",
        "Э": "\"",
        "Я": "Z", "Ч": "X", "С": "C", "М": "V", "И": "B",
        "Т": "N", "Ь": "M", "Б": "<", "Ю": ">",
        "Ё": "~",
        // Ukrainian-specific lowercase (keys that differ from Russian)
        "і": "s", "ї": "]", "є": "'", "ґ": "`",
        // Ukrainian-specific uppercase
        "І": "S", "Ї": "}", "Є": "\"", "Ґ": "~",
    ]

    /// Unicode scalar range for the Cyrillic block (U+0400–U+04FF).
    private static let cyrillicRange: ClosedRange<UInt32> = 0x0400...0x04FF

    /// Latin letters that visually overlap with Cyrillic letters.
    /// Used to validate mixed-script words against Cyrillic dictionaries.
    private static let latinToCyrillicLookalike: [Character: Character] = [
        "A": "А", "a": "а",
        "B": "В",
        "C": "С", "c": "с",
        "E": "Е", "e": "е",
        "H": "Н",
        "K": "К", "k": "к",
        "M": "М",
        "O": "О", "o": "о",
        "P": "Р", "p": "р",
        "T": "Т",
        "X": "Х", "x": "х",
        "Y": "У", "y": "у",
    ]

    /// QWERTY letters mapped to possible Cyrillic letters by keyboard position.
    /// Most keys map to one letter. `s`/`S` can be Russian or Ukrainian.
    private static let enToCyrillicVariants: [Character: [Character]] = [
        "q": ["й"], "w": ["ц"], "e": ["у"], "r": ["к"], "t": ["е"],
        "y": ["н"], "u": ["г"], "i": ["ш"], "o": ["щ"], "p": ["з"],
        "a": ["ф"], "s": ["ы", "і"], "d": ["в"], "f": ["а"], "g": ["п"],
        "h": ["р"], "j": ["о"], "k": ["л"], "l": ["д"],
        "z": ["я"], "x": ["ч"], "c": ["с"], "v": ["м"], "b": ["и"],
        "n": ["т"], "m": ["ь"],
        "Q": ["Й"], "W": ["Ц"], "E": ["У"], "R": ["К"], "T": ["Е"],
        "Y": ["Н"], "U": ["Г"], "I": ["Ш"], "O": ["Щ"], "P": ["З"],
        "A": ["Ф"], "S": ["Ы", "І"], "D": ["В"], "F": ["А"], "G": ["П"],
        "H": ["Р"], "J": ["О"], "K": ["Л"], "L": ["Д"],
        "Z": ["Я"], "X": ["Ч"], "C": ["С"], "V": ["М"], "B": ["И"],
        "N": ["Т"], "M": ["Ь"],
        // Punctuation keys that produce Cyrillic letters on RU/UK layouts
        ",": ["б"], "<": ["Б"],
        ".": ["ю"], ">": ["Ю"],
        ";": ["ж"], ":": ["Ж"],
        "'": ["э", "є"], "\"": ["Э", "Є"],
        "[": ["х"], "{": ["Х"],
        "]": ["ъ", "ї"], "}": ["Ъ", "Ї"],
        "`": ["ё", "ґ"], "~": ["Ё", "Ґ"],
    ]

    /// Returns `true` when every character in the word is a Cyrillic letter.
    static func isCyrillic(_ word: String) -> Bool {
        !word.isEmpty && word.unicodeScalars.allSatisfy { cyrillicRange.contains($0.value) }
    }

    /// Converts a Cyrillic string to its QWERTY English equivalent.
    /// Returns `nil` if any character has no mapping.
    static func convert(_ word: String) -> String? {
        var result = ""
        result.reserveCapacity(word.count)
        for ch in word {
            guard let mapped = cyrillicToEn[ch] else { return nil }
            result.append(mapped)
        }
        return result
    }

    /// Converts a word that may include both Cyrillic and Latin letters.
    /// Latin letters are preserved as-is. Returns `nil` if no Cyrillic
    /// characters were converted or if the word contains unsupported symbols.
    static func convertIncludingLatin(_ word: String) -> String? {
        var result = ""
        var convertedAnyCyrillic = false
        result.reserveCapacity(word.count)

        for ch in word {
            if let mapped = cyrillicToEn[ch] {
                result.append(mapped)
                convertedAnyCyrillic = true
            } else if ch.isASCII && ch.isLetter {
                result.append(ch)
            } else {
                return nil
            }
        }

        return convertedAnyCyrillic ? result : nil
    }

    /// Converts a mistyped English QWERTY word to a valid Cyrillic word
    /// when possible (e.g. `ghbdtn` -> `привет`).
    static func convertEnglishMistypeToValidCyrillic(_ word: String) -> String? {
        guard !word.isEmpty else { return nil }

        for candidate in buildCyrillicCandidates(from: word) {
            if isValidCyrillicWord(candidate) {
                return candidate
            }
        }

        return nil
    }

    // MARK: - Spell checking

    /// Unique tag so the spell checker doesn't accumulate shared state over time.
    private static let spellDocumentTag: Int = NSSpellChecker.uniqueSpellDocumentTag()

    /// Cyrillic language codes to check against the macOS spell checker,
    /// filtered to only those actually available on this system.
    private static let cyrillicLanguages: [String] = {
        let candidates = ["ru", "uk", "be", "bg", "sr", "mk"]
        let available = Set(NSSpellChecker.shared.availableLanguages)
        return candidates.filter { lang in
            available.contains(lang) || available.contains { $0.hasPrefix(lang + "_") || $0.hasPrefix(lang + "-") }
        }
    }()

    /// Returns `true` when the word is valid in any Cyrillic language
    /// according to the macOS spell checker.
    static func isValidCyrillicWord(_ word: String) -> Bool {
        let checker = NSSpellChecker.shared
        for lang in cyrillicLanguages {
            let range = checker.checkSpelling(
                of: word,
                startingAt: 0,
                language: lang,
                wrap: false,
                inSpellDocumentWithTag: spellDocumentTag,
                wordCount: nil
            )
            if range.location == NSNotFound {
                return true
            }
        }
        return false
    }

    /// Returns the language code (e.g. "uk", "ru") of the first Cyrillic language
    /// in which the word is valid, or `nil` if none match.
    static func cyrillicWordLanguage(_ word: String) -> String? {
        let checker = NSSpellChecker.shared
        for lang in cyrillicLanguages {
            let range = checker.checkSpelling(
                of: word,
                startingAt: 0,
                language: lang,
                wrap: false,
                inSpellDocumentWithTag: spellDocumentTag,
                wordCount: nil
            )
            if range.location == NSNotFound {
                return lang
            }
        }
        return nil
    }

    /// Returns `true` if the word is valid in a Cyrillic language,
    /// also considering Latin lookalike letters inside the word.
    static func isValidCyrillicWordConsideringLatinOverlap(_ word: String) -> Bool {
        guard !word.isEmpty else { return false }

        if isCyrillic(word) {
            return isValidCyrillicWord(word)
        }

        let normalized = normalizeLatinLookalikesToCyrillic(word)
        guard isCyrillic(normalized), normalized != word else {
            return false
        }

        return isValidCyrillicWord(normalized)
    }

    // MARK: - Shell command validation

    /// Common bash / zsh built-in commands that have no executable on disk.
    private static let shellBuiltins: Set<String> = [
        "cd", "echo", "export", "source", "alias", "unalias", "history",
        "jobs", "fg", "bg", "kill", "wait", "exit", "logout", "set", "unset",
        "read", "printf", "type", "pwd", "pushd", "popd", "dirs",
        "exec", "eval", "shift", "return", "break", "continue", "let",
        "declare", "typeset", "local", "readonly", "getopts", "enable",
        "help", "builtin", "command", "hash", "test", "trap", "ulimit",
        "umask", "disown", "suspend", "print", "setopt", "unsetopt",
        "autoload", "bindkey", "compdef", "emulate", "rehash", "which",
    ]

    /// Directories searched for installed executables (in addition to built-ins).
    private static let shellCommandDirs = [
        "/bin", "/usr/bin", "/usr/local/bin",
        "/sbin", "/usr/sbin",
        "/opt/homebrew/bin", "/opt/homebrew/sbin",
    ]

    /// Returns `true` when `word` is a shell built-in or an executable found
    /// in common PATH directories. Only accepts words made of letters, digits,
    /// hyphens, underscores, and dots (valid command-name characters).
    static func isShellCommand(_ word: String) -> Bool {
        guard !word.isEmpty,
              word.unicodeScalars.allSatisfy({ $0.value < 128 }),   // ASCII only
              word.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == "." })
        else { return false }

        if shellBuiltins.contains(word) { return true }

        let fm = FileManager.default
        for dir in shellCommandDirs {
            if fm.isExecutableFile(atPath: dir + "/" + word) { return true }
        }
        return false
    }

    /// Returns `true` when the word is a valid English word according to
    /// the macOS spell checker.
    static func isValidEnglishWord(_ word: String) -> Bool {
        let checker = NSSpellChecker.shared
        let range = checker.checkSpelling(
            of: word,
            startingAt: 0,
            language: "en",
            wrap: false,
            inSpellDocumentWithTag: spellDocumentTag,
            wordCount: nil
        )
        return range.location == NSNotFound
    }

    private static func normalizeLatinLookalikesToCyrillic(_ word: String) -> String {
        var result = ""
        result.reserveCapacity(word.count)
        for ch in word {
            result.append(latinToCyrillicLookalike[ch] ?? ch)
        }
        return result
    }

    private static func buildCyrillicCandidates(from word: String) -> [String] {
        let maxCandidates = 64
        var candidates = [""]

        for ch in word {
            guard let variants = enToCyrillicVariants[ch] else {
                return []
            }

            var next: [String] = []
            next.reserveCapacity(min(maxCandidates, candidates.count * variants.count))

            outer: for prefix in candidates {
                for variant in variants {
                    if next.count >= maxCandidates {
                        break outer
                    }
                    next.append(prefix + String(variant))
                }
            }

            candidates = next
            if candidates.isEmpty {
                return []
            }
        }

        return candidates
    }
}
