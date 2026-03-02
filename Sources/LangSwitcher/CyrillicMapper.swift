import Foundation

/// Maps Russian (Cyrillic) characters typed on an English QWERTY keyboard
/// back to the corresponding English characters.
enum CyrillicMapper {

    // MARK: - RU → EN mapping (ЙЦУКЕН → QWERTY)

    private static let ruToEn: [Character: Character] = [
        // lowercase
        "й": "q", "ц": "w", "у": "e", "к": "r", "е": "t",
        "н": "y", "г": "u", "ш": "i", "щ": "o", "з": "p",
        "х": "[", "ъ": "]",
        "ф": "a", "ы": "s", "в": "d", "а": "f", "п": "g",
        "р": "h", "о": "j", "л": "k", "д": "l", "ж": ";",
        "э": "'",
        "я": "z", "ч": "x", "с": "c", "м": "v", "и": "b",
        "т": "n", "ь": "m", "б": ",", "ю": ".",
        "ё": "`",
        // uppercase
        "Й": "Q", "Ц": "W", "У": "E", "К": "R", "Е": "T",
        "Н": "Y", "Г": "U", "Ш": "I", "Щ": "O", "З": "P",
        "Х": "{", "Ъ": "}",
        "Ф": "A", "Ы": "S", "В": "D", "А": "F", "П": "G",
        "Р": "H", "О": "J", "Л": "K", "Д": "L", "Ж": ":",
        "Э": "\"",
        "Я": "Z", "Ч": "X", "С": "C", "М": "V", "И": "B",
        "Т": "N", "Ь": "M", "Б": "<", "Ю": ">",
        "Ё": "~",
    ]

    /// Returns `true` when every character in the word is a known Cyrillic key.
    static func isCyrillic(_ word: String) -> Bool {
        !word.isEmpty && word.allSatisfy { ruToEn[$0] != nil }
    }

    /// Converts a Cyrillic string to its QWERTY English equivalent.
    /// Returns `nil` if any character has no mapping.
    static func convert(_ word: String) -> String? {
        var result = ""
        result.reserveCapacity(word.count)
        for ch in word {
            guard let mapped = ruToEn[ch] else { return nil }
            result.append(mapped)
        }
        return result
    }
}
