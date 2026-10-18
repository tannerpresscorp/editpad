import Foundation

/// How a file is stored on disk: encoding, byte order mark and line endings.
public struct TextFormat: Equatable, Sendable {
    public var encoding: TextEncoding
    public var lineEnding: LineEnding
    public var hasByteOrderMark: Bool

    public init(encoding: TextEncoding = .utf8, lineEnding: LineEnding = .lf, hasByteOrderMark: Bool = false) {
        self.encoding = encoding
        self.lineEnding = lineEnding
        self.hasByteOrderMark = hasByteOrderMark && encoding.supportsByteOrderMark
    }

    /// Format for brand-new documents: UTF-8, LF, no BOM.
    public static let `default` = TextFormat()
}

/// Text decoded from disk. `text` is always `\n`-normalized.
public struct DecodedText: Equatable, Sendable {
    public var text: String
    public var format: TextFormat

    public init(text: String, format: TextFormat) {
        self.text = text
        self.format = format
    }
}

/// Bytes ready to write, plus the format actually used.
///
/// `format` differs from the requested one only when the text could not be
/// represented in the requested encoding and the codec fell back to UTF-8.
public struct EncodedText: Equatable, Sendable {
    public var data: Data
    public var format: TextFormat
    public var didFallBackToUTF8: Bool
}

public enum TextCodecError: Error, Equatable {
    /// The data looks binary (contains NUL bytes outside UTF-16).
    case binaryData
}

/// Converts between file bytes and editable text.
public enum TextCodec {
    /// Decodes file contents, detecting encoding, BOM and line endings.
    ///
    /// Detection order: BOM (UTF-8, UTF-16 LE/BE), then strict UTF-8, then
    /// Windows-1252, then ISO Latin 1 (which accepts any byte sequence).
    public static func decode(_ data: Data) throws -> DecodedText {
        let bytes = [UInt8](data)

        if bytes.starts(with: TextEncoding.utf8.byteOrderMark) {
            return try finish(Data(bytes.dropFirst(3)), .utf8, bom: true)
        }
        if bytes.starts(with: TextEncoding.utf16LittleEndian.byteOrderMark) {
            return try finish(Data(bytes.dropFirst(2)), .utf16LittleEndian, bom: true)
        }
        if bytes.starts(with: TextEncoding.utf16BigEndian.byteOrderMark) {
            return try finish(Data(bytes.dropFirst(2)), .utf16BigEndian, bom: true)
        }

        if bytes.contains(0) {
            throw TextCodecError.binaryData
        }

        for encoding in [TextEncoding.utf8, .windows1252, .isoLatin1] {
            if let result = try? finish(data, encoding, bom: false) {
                return result
            }
        }
        throw TextCodecError.binaryData
    }

    /// Encodes `\n`-normalized text using `format`, falling back to UTF-8 when
    /// the text contains characters the requested encoding cannot represent.
    public static func encode(_ text: String, format: TextFormat) -> EncodedText {
        let onDisk = format.lineEnding.apply(to: text)

        if let body = format.encoding.encode(onDisk) {
            return EncodedText(data: withBOM(body, format), format: format, didFallBackToUTF8: false)
        }

        let fallback = TextFormat(encoding: .utf8, lineEnding: format.lineEnding, hasByteOrderMark: false)
        let body = Data(onDisk.utf8)
        return EncodedText(data: body, format: fallback, didFallBackToUTF8: true)
    }

    /// Whether `text` can be saved in `encoding` without falling back.
    public static func canEncode(_ text: String, as encoding: TextEncoding) -> Bool {
        switch encoding {
        case .utf8, .utf16LittleEndian, .utf16BigEndian:
            return true
        case .isoLatin1:
            return !text.unicodeScalars.contains { $0.value > 0xFF }
        case .windows1252:
            return encoding.encode(text) != nil
        }
    }

    // MARK: - Private

    private static func finish(_ body: Data, _ encoding: TextEncoding, bom: Bool) throws -> DecodedText {
        guard let raw = encoding.decode(body) else {
            throw TextCodecError.binaryData
        }
        let format = TextFormat(encoding: encoding, lineEnding: LineEnding.detect(in: raw), hasByteOrderMark: bom)
        return DecodedText(text: LineEnding.normalize(raw), format: format)
    }

    private static func withBOM(_ body: Data, _ format: TextFormat) -> Data {
        guard format.hasByteOrderMark else { return body }
        return Data(format.encoding.byteOrderMark) + body
    }
}
