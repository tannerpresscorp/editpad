import XCTest
@testable import EditPadKit

final class LineEndingTests: XCTestCase {
    func testDetectsLF() {
        XCTAssertEqual(LineEnding.detect(in: "a\nb\nc"), .lf)
    }

    func testDetectsCRLF() {
        XCTAssertEqual(LineEnding.detect(in: "a\r\nb\r\nc"), .crlf)
    }

    func testDetectsCR() {
        XCTAssertEqual(LineEnding.detect(in: "a\rb\rc"), .cr)
    }

    func testTrailingCRCounts() {
        XCTAssertEqual(LineEnding.detect(in: "a\r"), .cr)
    }

    func testNoLineBreaksDefaultsToLF() {
        XCTAssertEqual(LineEnding.detect(in: "single line"), .lf)
        XCTAssertEqual(LineEnding.detect(in: ""), .lf)
    }

    func testDominantEndingWinsInMixedText() {
        XCTAssertEqual(LineEnding.detect(in: "a\r\nb\r\nc\nd"), .crlf)
        XCTAssertEqual(LineEnding.detect(in: "a\nb\nc\r\nd"), .lf)
    }

    func testTieResolvesToLF() {
        XCTAssertEqual(LineEnding.detect(in: "a\r\nb\nc"), .lf)
    }

    func testNormalizeConvertsAllBreaksToLF() {
        XCTAssertEqual(LineEnding.normalize("a\r\nb\rc\nd"), "a\nb\nc\nd")
    }

    func testNormalizeIsNoOpWithoutCR() {
        XCTAssertEqual(LineEnding.normalize("a\nb"), "a\nb")
    }

    func testApplyRoundTrips() {
        for ending in LineEnding.allCases {
            let onDisk = ending.apply(to: "one\ntwo\n")
            XCTAssertEqual(LineEnding.normalize(onDisk), "one\ntwo\n")
            XCTAssertEqual(LineEnding.detect(in: onDisk), ending)
        }
    }
}
