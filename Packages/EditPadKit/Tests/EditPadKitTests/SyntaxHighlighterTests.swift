import XCTest
@testable import EditPadKit

final class SyntaxHighlighterTests: XCTestCase {
    /// Returns (substring, kind) pairs so assertions read naturally.
    private func tokens(_ text: String, _ language: SyntaxLanguage) -> [(String, SyntaxTokenKind)] {
        let ns = text as NSString
        return SyntaxHighlighter(language: language).tokens(in: text).map { (ns.substring(with: $0.range), $0.kind) }
    }

    private func kind(of fragment: String, in text: String, _ language: SyntaxLanguage) -> SyntaxTokenKind? {
        tokens(text, language).first { $0.0 == fragment }?.1
    }

    func testSwiftBasics() {
        let code = """
        // greet the user
        @MainActor func greet(name: String) -> Int {
            let message = "Hello, \\(name) // not a comment"
            return 42
        }
        """
        XCTAssertEqual(kind(of: "// greet the user", in: code, .swift), .comment)
        XCTAssertEqual(kind(of: "@MainActor", in: code, .swift), .attribute)
        XCTAssertEqual(kind(of: "func", in: code, .swift), .keyword)
        XCTAssertEqual(kind(of: "String", in: code, .swift), .type)
        XCTAssertEqual(kind(of: "greet", in: code, .swift), .function)
        XCTAssertEqual(kind(of: "42", in: code, .swift), .number)
        XCTAssertEqual(kind(of: "\"Hello, \\(name) // not a comment\"", in: code, .swift), .string)
    }

    func testKeywordsInsideStringsAndCommentsAreNotColored() {
        let result = tokens("let s = \"return if\" /* func */", .swift)
        XCTAssertFalse(result.contains { $0.0 == "return" || $0.0 == "func" })
    }

    func testTokensDoNotOverlapAndAreSorted() {
        let code = "def f(x):\n    return \"\"\"doc # not comment\"\"\" # real\n"
        let raw = SyntaxHighlighter(language: .python).tokens(in: code)
        for (a, b) in zip(raw, raw.dropFirst()) {
            XCTAssertLessThanOrEqual(a.range.location + a.range.length, b.range.location)
        }
        XCTAssertEqual(kind(of: "# real", in: code, .python), .comment)
        XCTAssertEqual(kind(of: "\"\"\"doc # not comment\"\"\"", in: code, .python), .string)
    }

    func testUnterminatedBlockCommentRunsToEnd() {
        let code = "int a; /* open\nint b;"
        XCTAssertEqual(kind(of: "/* open\nint b;", in: code, .c), .comment)
    }

    func testJSONKeysAreProperties() {
        let json = #"{"name": "EditPad", "count": 3, "ok": true}"#
        XCTAssertEqual(kind(of: #""name""#, in: json, .json), .property)
        XCTAssertEqual(kind(of: #""EditPad""#, in: json, .json), .string)
        XCTAssertEqual(kind(of: "3", in: json, .json), .number)
        XCTAssertEqual(kind(of: "true", in: json, .json), .literal)
    }

    func testYAMLKeysAndComments() {
        let yaml = "name: CI\non:\n  push: # trigger\n    branches: [main]\n"
        XCTAssertEqual(kind(of: "name", in: yaml, .yaml), .property)
        XCTAssertEqual(kind(of: "branches", in: yaml, .yaml), .property)
        XCTAssertEqual(kind(of: "# trigger", in: yaml, .yaml), .comment)
    }

    func testRustLifetimeIsNotAString() {
        let code = "fn get<'a>(s: &'a str) -> char { 'x' }"
        XCTAssertEqual(kind(of: "'x'", in: code, .rust), .string)
        XCTAssertFalse(tokens(code, .rust).contains { $0.0.hasPrefix("'a") })
    }

    func testHTMLTagsAttributesAndComments() {
        let html = #"<!-- nav --><a href="/home" class='x'>Home &amp; away</a>"#
        XCTAssertEqual(kind(of: "<!-- nav -->", in: html, .html), .comment)
        XCTAssertEqual(kind(of: "<a", in: html, .html), .tag)
        XCTAssertEqual(kind(of: "href", in: html, .html), .property)
        XCTAssertEqual(kind(of: #""/home""#, in: html, .html), .string)
        XCTAssertEqual(kind(of: "&amp;", in: html, .html), .literal)
        XCTAssertNil(kind(of: "Home", in: html, .html))
    }

    func testMarkdown() {
        let md = "# Title\n\nSome **bold** text and `code`.\n\n```\nlet x = 1\n```\n- item\n[link](https://example.com)\n"
        XCTAssertEqual(kind(of: "# Title", in: md, .markdown), .heading)
        XCTAssertEqual(kind(of: "**bold**", in: md, .markdown), .emphasis)
        XCTAssertEqual(kind(of: "`code`", in: md, .markdown), .string)
        XCTAssertEqual(kind(of: "```\nlet x = 1\n```", in: md, .markdown), .string)
        XCTAssertEqual(kind(of: "[link](https://example.com)", in: md, .markdown), .link)
        XCTAssertEqual(kind(of: "-", in: md, .markdown), .keyword)
    }

    func testShellVariablesAndComments() {
        let sh = "#!/bin/bash\necho \"$HOME\" # done\nif [ $# -gt 0 ]; then exit 1; fi"
        XCTAssertEqual(kind(of: "#!/bin/bash", in: sh, .shell), .comment)
        XCTAssertEqual(kind(of: "# done", in: sh, .shell), .comment)
        XCTAssertEqual(kind(of: "$#", in: sh, .shell), .property)
        XCTAssertEqual(kind(of: "fi", in: sh, .shell), .keyword)
    }

    func testSQLKeywordsAreCaseInsensitive() {
        let sql = "SELECT id FROM users where name = 'O''Brien' -- note"
        XCTAssertEqual(kind(of: "SELECT", in: sql, .sql), .keyword)
        XCTAssertEqual(kind(of: "where", in: sql, .sql), .keyword)
        XCTAssertEqual(kind(of: "'O''Brien'", in: sql, .sql), .string)
        XCTAssertEqual(kind(of: "-- note", in: sql, .sql), .comment)
    }

    func testLuaLongBracketsUseBackreferences() {
        let lua = "--[==[ long\ncomment ]==]\nlocal s = [[raw]]"
        XCTAssertEqual(kind(of: "--[==[ long\ncomment ]==]", in: lua, .lua), .comment)
        XCTAssertEqual(kind(of: "[[raw]]", in: lua, .lua), .string)
        XCTAssertEqual(kind(of: "local", in: lua, .lua), .keyword)
    }

    func testRangesAreUTF16() {
        let code = "let 👋 = \"hi\""
        let token = SyntaxHighlighter(language: .swift).tokens(in: code).first { $0.kind == .string }
        // "let " = 4, emoji = 2 UTF-16 units, " = " = 3 → string starts at 9.
        XCTAssertEqual(token?.range, NSRange(location: 9, length: 4))
    }

    func testPlainTextHasNoTokens() {
        XCTAssertTrue(SyntaxHighlighter(language: .plainText).tokens(in: "if let x = 1").isEmpty)
    }

    func testBackreferenceShifting() {
        XCTAssertEqual(SyntaxHighlighter.captureGroupCount(in: #"(a)(?:b)\(c\)[(]"#), 1)
        XCTAssertEqual(SyntaxHighlighter.shiftBackreferences(in: #"(x)\1\n"#, by: 3), #"(x)\4\n"#)
    }
}
