import Foundation

/// Counts shown in the editor's status bar.
public struct TextStatistics: Equatable, Sendable {
    /// User-perceived characters (grapheme clusters).
    public let characters: Int
    /// Runs of non-whitespace characters.
    public let words: Int
    /// Lines, counting an empty document as one line.
    public let lines: Int

    public init(characters: Int, words: Int, lines: Int) {
        self.characters = characters
        self.words = words
        self.lines = lines
    }

    /// Computes statistics for `\n`-normalized text in a single pass over
    /// unicode scalars, plus one grapheme count.
    public init(_ text: String) {
        var words = 0
        var lines = 1
        var inWord = false
        for scalar in text.unicodeScalars {
            if scalar == "\n" { lines += 1 }
            if scalar.properties.isWhitespace {
                inWord = false
            } else if !inWord {
                inWord = true
                words += 1
            }
        }
        self.init(characters: text.count, words: words, lines: lines)
    }

    /// Compact summary, e.g. "12 words · 64 chars · 3 lines".
    public var summary: String {
        "\(Self.plural(words, "word")) · \(Self.plural(characters, "char")) · \(Self.plural(lines, "line"))"
    }

    private static func plural(_ count: Int, _ noun: String) -> String {
        "\(count.formatted()) \(noun)\(count == 1 ? "" : "s")"
    }
}
