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

    // MARK: - Spell checking

    /// Cyrillic language codes to check against the macOS spell checker.
    private static let cyrillicLanguages = ["ru", "uk", "be", "bg", "sr", "mk"]

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
                inSpellDocumentWithTag: 0,
                wordCount: nil
            )
            if range.location == NSNotFound {
                return true
            }
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
            inSpellDocumentWithTag: 0,
            wordCount: nil
        )
        return range.location == NSNotFound
    }
}
