import Foundation

/// What the Tab key inserts.
public enum IndentStyle: String, CaseIterable, Sendable, Identifiable {
    case tab
    case twoSpaces
    case fourSpaces

    public var id: String { rawValue }

    /// One level of indentation.
    public var unit: String {
        switch self {
        case .tab: return "\t"
        case .twoSpaces: return "  "
        case .fourSpaces: return "    "
        }
    }

    public var displayName: String {
        switch self {
        case .tab: return "Tab Character"
        case .twoSpaces: return "2 Spaces"
        case .fourSpaces: return "4 Spaces"
        }
    }
}

/// Auto-indent helpers. Locations are UTF-16 offsets, matching UITextView.
public enum Indentation {
    /// Text to insert when Return is pressed at `location` in `text`.
    ///
    /// Copies the current line's leading whitespace, and adds one more level
    /// after an opening bracket (or a trailing colon in Python and YAML).
    public static func newline(in text: String, at location: Int, style: IndentStyle, language: SyntaxLanguage) -> String {
        let nsText = text as NSString
        let location = min(max(location, 0), nsText.length)
        let lineRange = nsText.lineRange(for: NSRange(location: location, length: 0))
        let beforeCursor = nsText.substring(with: NSRange(location: lineRange.location, length: location - lineRange.location))

        let leading = String(beforeCursor.prefix { $0 == " " || $0 == "\t" })
        let trimmed = beforeCursor.trimmingCharacters(in: .whitespaces)

        var opensBlock = false
        if let last = trimmed.last {
            switch last {
            case "{", "[", "(":
                opensBlock = true
            case ":":
                opensBlock = language == .python || language == .yaml
            default:
                opensBlock = false
            }
        }
        return "\n" + leading + (opensBlock ? style.unit : "")
    }
}
