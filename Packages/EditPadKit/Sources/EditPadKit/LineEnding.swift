import Foundation

/// The newline convention a file uses on disk.
///
/// While a document is open, EditPad keeps its text normalized to `\n`.
/// The original convention is remembered and restored when the file is saved.
public enum LineEnding: String, CaseIterable, Sendable, Identifiable {
    case lf
    case crlf
    case cr

    public var id: String { rawValue }

    /// The characters written to disk for this convention.
    public var sequence: String {
        switch self {
        case .lf: return "\n"
        case .crlf: return "\r\n"
        case .cr: return "\r"
        }
    }

    /// Short label for the status bar, e.g. "LF".
    public var label: String {
        switch self {
        case .lf: return "LF"
        case .crlf: return "CRLF"
        case .cr: return "CR"
        }
    }

    /// Longer label for menus.
    public var displayName: String {
        switch self {
        case .lf: return "LF (macOS, Linux)"
        case .crlf: return "CRLF (Windows)"
        case .cr: return "CR (Classic Mac)"
        }
    }

    /// Detects the dominant line ending in `text`.
    ///
    /// Counts each convention and returns the most common one. Ties and text
    /// without any line breaks resolve to `.lf`.
    public static func detect(in text: String) -> LineEnding {
        var lf = 0, crlf = 0, cr = 0
        var previousWasCR = false
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\r":
                if previousWasCR { cr += 1 }
                previousWasCR = true
            case "\n":
                if previousWasCR { crlf += 1 } else { lf += 1 }
                previousWasCR = false
            default:
                if previousWasCR { cr += 1 }
                previousWasCR = false
            }
        }
        if previousWasCR { cr += 1 }

        if crlf > lf && crlf >= cr { return .crlf }
        if cr > lf && cr > crlf { return .cr }
        return .lf
    }

    /// Converts every line break in `text` (LF, CRLF or CR) to `\n`.
    public static func normalize(_ text: String) -> String {
        guard text.unicodeScalars.contains("\r") else { return text }
        return text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    /// Converts `\n`-normalized text to this convention.
    public func apply(to normalizedText: String) -> String {
        self == .lf ? normalizedText : normalizedText.replacingOccurrences(of: "\n", with: sequence)
    }
}
