import XCTest
@testable import EditPadKit

final class SyntaxLanguageTests: XCTestCase {
    func testDetectsByExtension() {
        XCTAssertEqual(SyntaxLanguage.detect(fileName: "main.swift"), .swift)
        XCTAssertEqual(SyntaxLanguage.detect(fileName: "App.TSX"), .typescript)
        XCTAssertEqual(SyntaxLanguage.detect(fileName: "styles.scss"), .css)
        XCTAssertEqual(SyntaxLanguage.detect(fileName: "config.yml"), .yaml)
        XCTAssertEqual(SyntaxLanguage.detect(fileName: "lib.rs"), .rust)
        XCTAssertEqual(SyntaxLanguage.detect(fileName: "README.md"), .markdown)
    }

    func testDetectsByFileName() {
        XCTAssertEqual(SyntaxLanguage.detect(fileName: "Makefile"), .makefile)
        XCTAssertEqual(SyntaxLanguage.detect(fileName: "Dockerfile"), .dockerfile)
        XCTAssertEqual(SyntaxLanguage.detect(fileName: "Dockerfile.dev"), .dockerfile)
        XCTAssertEqual(SyntaxLanguage.detect(fileName: "Gemfile"), .ruby)
        XCTAssertEqual(SyntaxLanguage.detect(fileName: ".zshrc"), .shell)
        XCTAssertEqual(SyntaxLanguage.detect(fileName: ".env.local"), .ini)
        XCTAssertEqual(SyntaxLanguage.detect(fileName: ".gitignore"), .ini)
    }

    func testDetectsByShebang() {
        XCTAssertEqual(SyntaxLanguage.detect(fileName: "deploy", firstLine: "#!/usr/bin/env python3"), .python)
        XCTAssertEqual(SyntaxLanguage.detect(fileName: "run", firstLine: "#!/bin/bash"), .shell)
        XCTAssertEqual(SyntaxLanguage.detect(fileName: "tool", firstLine: "#!/usr/bin/env node"), .javascript)
    }

    func testUnknownIsPlainText() {
        XCTAssertEqual(SyntaxLanguage.detect(fileName: "notes.txt"), .plainText)
        XCTAssertEqual(SyntaxLanguage.detect(fileName: "LICENSE"), .plainText)
        XCTAssertEqual(SyntaxLanguage.detect(fileName: ""), .plainText)
    }

    func testEveryLanguageCompiles() {
        for language in SyntaxLanguage.allCases {
            let highlighter = SyntaxHighlighter(language: language)
            XCTAssertEqual(highlighter.isEnabled, language != .plainText, "\(language)")
            // Exercise every rule on mixed input without crashing.
            _ = highlighter.tokens(in: "x = \"a\" # c // d /* e */ 'f' 1.5 Foo bar() <a b=\"c\">\n- k: v\n")
        }
    }
}
