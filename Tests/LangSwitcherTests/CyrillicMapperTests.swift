import XCTest
@testable import LangSwitcher

final class CyrillicMapperTests: XCTestCase {

    func testNormalizedPotentialCyrillicWordPreservesApostrophes() {
        XCTAssertEqual(CyrillicMapper.normalizedPotentialCyrillicWord("п'ять"), "п'ять")
        XCTAssertEqual(CyrillicMapper.normalizedPotentialCyrillicWord("об\u{2019}єкт"), "об\u{2019}єкт")
    }

    func testNormalizedPotentialCyrillicWordPreservesHyphenatedWords() {
        XCTAssertEqual(CyrillicMapper.normalizedPotentialCyrillicWord("по-русски"), "по-русски")
    }

    func testNormalizedPotentialCyrillicWordMapsLowercaseLookalikes() {
        XCTAssertEqual(CyrillicMapper.normalizedPotentialCyrillicWord("дom"), "дом")
    }

    func testNormalizedPotentialCyrillicWordRejectsUnsupportedCharacters() {
        XCTAssertNil(CyrillicMapper.normalizedPotentialCyrillicWord("дом!"))
        XCTAssertNil(CyrillicMapper.normalizedPotentialCyrillicWord("hello"))
    }

    func testValidCyrillicWordConsideringLatinOverlapAcceptsLowercaseLookalikes() throws {
        try skipUnlessSpellCheckerRecognizes("дом")
        XCTAssertTrue(CyrillicMapper.isValidCyrillicWordConsideringLatinOverlap("дom"))
    }

    func testValidCyrillicWordConsideringLatinOverlapAcceptsWordsWithApostrophes() throws {
        try skipUnlessSpellCheckerRecognizes("п'ять")
        XCTAssertTrue(CyrillicMapper.isValidCyrillicWordConsideringLatinOverlap("п'ять"))
    }

    private func skipUnlessSpellCheckerRecognizes(_ word: String) throws {
        guard CyrillicMapper.isValidCyrillicWord(word) else {
            throw XCTSkip("The current macOS spell-check dictionaries do not recognize \(word).")
        }
    }
}
