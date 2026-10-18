import Foundation

/// Table-driven Windows-1252 and ISO Latin 1 conversion.
///
/// Foundation's single-byte decoders differ between Apple platforms and
/// Linux (Linux rejects bytes 0x80–0x9F), so EditPad converts these
/// encodings itself to behave identically everywhere.
enum SingleByteCodec {
    /// Windows-1252 code points for bytes 0x80–0x9F. `nil` marks the five
    /// undefined bytes (0x81, 0x8D, 0x8F, 0x90, 0x9D).
    private static let windows1252High: [UInt32?] = [
        0x20AC, nil, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021,
        0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, nil, 0x017D, nil,
        nil, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
        0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, nil, 0x017E, 0x0178,
    ]

    private static let windows1252Reverse: [UInt32: UInt8] = {
        var map: [UInt32: UInt8] = [:]
        for (offset, codePoint) in windows1252High.enumerated() {
            if let codePoint { map[codePoint] = UInt8(0x80 + offset) }
        }
        return map
    }()

    static func decode(_ data: Data, as encoding: TextEncoding) -> String? {
        var scalars = String.UnicodeScalarView()
        scalars.reserveCapacity(data.count)
        for byte in data {
            let value: UInt32
            if encoding == .windows1252, (0x80...0x9F).contains(byte) {
                guard let mapped = windows1252High[Int(byte - 0x80)] else { return nil }
                value = mapped
            } else {
                value = UInt32(byte)
            }
            guard let scalar = Unicode.Scalar(value) else { return nil }
            scalars.append(scalar)
        }
        return String(scalars)
    }

    static func encode(_ text: String, as encoding: TextEncoding) -> Data? {
        var bytes = [UInt8]()
        bytes.reserveCapacity(text.unicodeScalars.count)
        for scalar in text.unicodeScalars {
            let value = scalar.value
            if encoding == .windows1252 {
                if value < 0x80 || (0xA0...0xFF).contains(value) {
                    bytes.append(UInt8(value))
                } else if let byte = windows1252Reverse[value] {
                    bytes.append(byte)
                } else {
                    return nil
                }
            } else {
                guard value <= 0xFF else { return nil }
                bytes.append(UInt8(value))
            }
        }
        return Data(bytes)
    }
}
