import Foundation

/// Text encodings EditPad can read and write.
public enum TextEncoding: String, CaseIterable, Sendable, Identifiable {
    case utf8
    case utf16LittleEndian
    case utf16BigEndian
    case windows1252
    case isoLatin1

    public var id: String { rawValue }

    /// Decodes `data` (without a BOM) or returns `nil` if it is not valid in this encoding.
    func decode(_ data: Data) -> String? {
        switch self {
        case .utf8: return String(data: data, encoding: .utf8)
        case .utf16LittleEndian: return String(data: data, encoding: .utf16LittleEndian)
        case .utf16BigEndian: return String(data: data, encoding: .utf16BigEndian)
        case .windows1252, .isoLatin1: return SingleByteCodec.decode(data, as: self)
        }
    }

    /// Encodes `text` (without a BOM) or returns `nil` if a character cannot be represented.
    func encode(_ text: String) -> Data? {
        switch self {
        case .utf8: return Data(text.utf8)
        case .utf16LittleEndian: return text.data(using: .utf16LittleEndian)
        case .utf16BigEndian: return text.data(using: .utf16BigEndian)
        case .windows1252, .isoLatin1: return SingleByteCodec.encode(text, as: self)
        }
    }

    /// Short label for the status bar.
    public var label: String {
        switch self {
        case .utf8: return "UTF-8"
        case .utf16LittleEndian: return "UTF-16 LE"
        case .utf16BigEndian: return "UTF-16 BE"
        case .windows1252: return "Windows-1252"
        case .isoLatin1: return "ISO Latin 1"
        }
    }

    /// Byte order mark written before the content when a BOM is requested.
    public var byteOrderMark: [UInt8] {
        switch self {
        case .utf8: return [0xEF, 0xBB, 0xBF]
        case .utf16LittleEndian: return [0xFF, 0xFE]
        case .utf16BigEndian: return [0xFE, 0xFF]
        case .windows1252, .isoLatin1: return []
        }
    }

    /// Whether this encoding can carry a byte order mark.
    public var supportsByteOrderMark: Bool { !byteOrderMark.isEmpty }
}
