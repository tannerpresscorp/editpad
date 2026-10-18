import XCTest
@testable import EditPadKit

final class TextCodecTests: XCTestCase {
    func testDecodesPlainUTF8() throws {
        let decoded = try TextCodec.decode(Data("héllo 👋\nworld".utf8))
        XCTAssertEqual(decoded.text, "héllo 👋\nworld")
        XCTAssertEqual(decoded.format, TextFormat(encoding: .utf8, lineEnding: .lf, hasByteOrderMark: false))
    }

    func testDecodesEmptyFile() throws {
        let decoded = try TextCodec.decode(Data())
        XCTAssertEqual(decoded.text, "")
        XCTAssertEqual(decoded.format, .default)
    }

    func testDecodesUTF8WithBOMAndCRLF() throws {
        let data = Data([0xEF, 0xBB, 0xBF]) + Data("a\r\nb".utf8)
        let decoded = try TextCodec.decode(data)
        XCTAssertEqual(decoded.text, "a\nb")
        XCTAssertEqual(decoded.format, TextFormat(encoding: .utf8, lineEnding: .crlf, hasByteOrderMark: true))
    }

    func testDecodesUTF16LittleEndianWithBOM() throws {
        let data = Data([0xFF, 0xFE]) + "hi\n".data(using: .utf16LittleEndian)!
        let decoded = try TextCodec.decode(data)
        XCTAssertEqual(decoded.text, "hi\n")
        XCTAssertEqual(decoded.format.encoding, .utf16LittleEndian)
        XCTAssertTrue(decoded.format.hasByteOrderMark)
    }

    func testDecodesUTF16BigEndianWithBOM() throws {
        let data = Data([0xFE, 0xFF]) + "hi".data(using: .utf16BigEndian)!
        let decoded = try TextCodec.decode(data)
        XCTAssertEqual(decoded.text, "hi")
        XCTAssertEqual(decoded.format.encoding, .utf16BigEndian)
    }

    func testFallsBackToWindows1252ForInvalidUTF8() throws {
        // 0x93 / 0x94 are curly quotes in Windows-1252 and invalid as UTF-8.
        let decoded = try TextCodec.decode(Data([0x93, 0x68, 0x69, 0x94]))
        XCTAssertEqual(decoded.format.encoding, .windows1252)
        XCTAssertEqual(decoded.text, "\u{201C}hi\u{201D}")
    }

    func testFallsBackToLatin1ForBytesUndefinedInWindows1252() throws {
        // 0x81 is undefined in Windows-1252 but valid (a C1 control) in Latin 1.
        let decoded = try TextCodec.decode(Data([0x61, 0x81, 0xE9]))
        XCTAssertEqual(decoded.format.encoding, .isoLatin1)
        XCTAssertEqual(decoded.text, "a\u{81}é")
    }

    func testWindows1252EncodesSmartPunctuation() {
        let encoded = TextCodec.encode("\u{201C}€\u{201D}", format: TextFormat(encoding: .windows1252))
        XCTAssertEqual([UInt8](encoded.data), [0x93, 0x80, 0x94])
        XCTAssertFalse(encoded.didFallBackToUTF8)
    }

    func testRejectsBinaryData() {
        XCTAssertThrowsError(try TextCodec.decode(Data([0x89, 0x50, 0x4E, 0x47, 0x00, 0x00]))) { error in
            XCTAssertEqual(error as? TextCodecError, .binaryData)
        }
    }

    func testEncodeRestoresLineEndingsAndBOM() {
        let format = TextFormat(encoding: .utf8, lineEnding: .crlf, hasByteOrderMark: true)
        let encoded = TextCodec.encode("a\nb", format: format)
        XCTAssertEqual([UInt8](encoded.data), [0xEF, 0xBB, 0xBF, 0x61, 0x0D, 0x0A, 0x62])
        XCTAssertFalse(encoded.didFallBackToUTF8)
    }

    func testRoundTripPreservesBytes() throws {
        let originals: [Data] = [
            Data("plain\nlf\n".utf8),
            Data("windows\r\nfile\r\n".utf8),
            Data([0xEF, 0xBB, 0xBF]) + Data("bom\n".utf8),
            Data([0xFF, 0xFE]) + "wide\r\n".data(using: .utf16LittleEndian)!,
            Data([0x93, 0x71, 0x94, 0x0D]),
        ]
        for original in originals {
            let decoded = try TextCodec.decode(original)
            let encoded = TextCodec.encode(decoded.text, format: decoded.format)
            XCTAssertEqual(encoded.data, original, "round trip changed \(decoded.format)")
        }
    }

    func testEncodeFallsBackToUTF8WhenUnrepresentable() {
        let format = TextFormat(encoding: .isoLatin1, lineEnding: .lf)
        let encoded = TextCodec.encode("emoji 🎉", format: format)
        XCTAssertTrue(encoded.didFallBackToUTF8)
        XCTAssertEqual(encoded.format.encoding, .utf8)
        XCTAssertEqual(String(data: encoded.data, encoding: .utf8), "emoji 🎉")
    }

    func testCanEncode() {
        XCTAssertTrue(TextCodec.canEncode("café", as: .isoLatin1))
        XCTAssertFalse(TextCodec.canEncode("🎉", as: .isoLatin1))
        XCTAssertTrue(TextCodec.canEncode("🎉", as: .utf16BigEndian))
    }

    func testBOMIgnoredForEncodingsWithoutOne() {
        let format = TextFormat(encoding: .windows1252, lineEnding: .lf, hasByteOrderMark: true)
        XCTAssertFalse(format.hasByteOrderMark)
    }
}
