import XCTest
@testable import EditPadKit

final class IndentationTests: XCTestCase {
    func testKeepsLeadingWhitespace() {
        let text = "    let x = 1"
        XCTAssertEqual(Indentation.newline(in: text, at: 13, style: .fourSpaces, language: .swift), "\n    ")
    }

    func testIndentsAfterOpeningBrace() {
        let text = "func f() {"
        XCTAssertEqual(Indentation.newline(in: text, at: 10, style: .fourSpaces, language: .swift), "\n    ")
        XCTAssertEqual(Indentation.newline(in: text, at: 10, style: .tab, language: .swift), "\n\t")
    }

    func testIndentsAfterColonOnlyForPythonAndYAML() {
        let text = "  if ready:"
        XCTAssertEqual(Indentation.newline(in: text, at: 11, style: .twoSpaces, language: .python), "\n    ")
        XCTAssertEqual(Indentation.newline(in: text, at: 11, style: .twoSpaces, language: .swift), "\n  ")
    }

    func testUsesOnlyTextBeforeCursor() {
        let text = "\tfoo {bar}"
        // Cursor right after "{": the closing part of the line is ignored.
        XCTAssertEqual(Indentation.newline(in: text, at: 6, style: .tab, language: .c), "\n\t\t")
    }

    func testWorksOnLaterLines() {
        let text = "a\n\tb\n"
        XCTAssertEqual(Indentation.newline(in: text, at: 4, style: .tab, language: .plainText), "\n\t")
    }

    func testClampsOutOfRangeLocation() {
        XCTAssertEqual(Indentation.newline(in: "x", at: 99, style: .tab, language: .plainText), "\n")
    }
}
