import XCTest
@testable import EditPadKit

final class TextStatisticsTests: XCTestCase {
    func testEmptyText() {
        XCTAssertEqual(TextStatistics(""), TextStatistics(characters: 0, words: 0, lines: 1))
    }

    func testCountsWordsAcrossWhitespace() {
        let stats = TextStatistics("  hello   world\tagain\n\nnext ")
        XCTAssertEqual(stats.words, 4)
        XCTAssertEqual(stats.lines, 3)
    }

    func testCountsGraphemesNotScalars() {
        // Family emoji is several scalars but one character.
        XCTAssertEqual(TextStatistics("👨‍👩‍👧 é").characters, 3)
    }

    func testTrailingNewlineStartsNewLine() {
        XCTAssertEqual(TextStatistics("a\n").lines, 2)
    }

    func testSummaryPluralization() {
        XCTAssertEqual(TextStatistics(characters: 1, words: 1, lines: 1).summary, "1 word · 1 char · 1 line")
        XCTAssertEqual(TextStatistics(characters: 0, words: 2, lines: 3).summary, "2 words · 0 chars · 3 lines")
    }
}
