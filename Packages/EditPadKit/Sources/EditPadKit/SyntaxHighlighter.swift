import Foundation

/// A colored range in a document. `range` is in UTF-16 units (NSString/NSTextStorage).
public struct SyntaxToken: Equatable, Sendable {
    public let range: NSRange
    public let kind: SyntaxTokenKind

    public init(range: NSRange, kind: SyntaxTokenKind) {
        self.range = range
        self.kind = kind
    }
}

/// Regular-expression tokenizer for lightweight syntax highlighting.
///
/// It is deliberately approximate: it colors comments, strings, keywords,
/// numbers and a few language-specific constructs, but it does not parse.
/// Create one per language and reuse it; compiling the expressions is the
/// expensive part.
public final class SyntaxHighlighter {
    public let language: SyntaxLanguage

    private struct CompiledRule {
        let regex: NSRegularExpression
        let kind: SyntaxTokenKind
        let group: Int
    }

    /// Pass one: comments and strings combined into a single alternation.
    private let spanRegex: NSRegularExpression?
    private let spanKinds: [SyntaxTokenKind]
    /// Capture-group number wrapping each span rule in `spanRegex`.
    private let spanGroups: [Int]
    /// Pass two, in priority order.
    private let rules: [CompiledRule]

    public init(language: SyntaxLanguage) {
        self.language = language
        guard let grammar = SyntaxGrammar.make(for: language) else {
            spanRegex = nil
            spanKinds = []
            spanGroups = []
            rules = []
            return
        }

        if grammar.spans.isEmpty {
            spanRegex = nil
            spanKinds = []
            spanGroups = []
        } else {
            spanRegex = try? NSRegularExpression(pattern: Self.joinAlternatives(grammar.spans), options: [])
            assert(spanRegex != nil, "Invalid \(language) span patterns")
            spanKinds = grammar.spans.map(\.kind)
            spanGroups = Self.wrapperGroupNumbers(grammar.spans)
        }

        var compiled: [CompiledRule] = []
        func add(_ pattern: String, _ kind: SyntaxTokenKind, group: Int = 0, options: NSRegularExpression.Options = []) {
            if let regex = try? NSRegularExpression(pattern: pattern, options: options) {
                compiled.append(CompiledRule(regex: regex, kind: kind, group: group))
            } else {
                assertionFailure("Invalid \(language) pattern: \(pattern)")
            }
        }
        for rule in grammar.rules {
            add(rule.pattern, rule.kind, group: rule.group, options: rule.options)
        }
        if !grammar.keywords.isEmpty {
            add(Self.wordAlternation(grammar.keywords), .keyword,
                options: grammar.caseInsensitiveKeywords ? .caseInsensitive : [])
        }
        if !grammar.literals.isEmpty {
            add(Self.wordAlternation(grammar.literals), .literal,
                options: grammar.caseInsensitiveKeywords ? .caseInsensitive : [])
        }
        if grammar.highlightsTypes { add(Patterns.type, .type) }
        if grammar.highlightsCalls { add(Patterns.call, .function) }
        if grammar.highlightsNumbers { add(Patterns.number, .number) }
        rules = compiled
    }

    /// Whether this language has any highlighting rules.
    public var isEnabled: Bool { spanRegex != nil || !rules.isEmpty }

    /// Tokens for `text`, sorted by location and never overlapping.
    public func tokens(in text: String) -> [SyntaxToken] {
        guard isEnabled else { return [] }
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        var tokens: [SyntaxToken] = []
        var covered = IndexSet()

        if let spanRegex {
            let spanKinds = self.spanKinds
            let spanGroups = self.spanGroups
            spanRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
                guard let match, match.range.length > 0 else { return }
                for (index, kind) in spanKinds.enumerated() {
                    let range = match.range(at: spanGroups[index])
                    if range.location != NSNotFound {
                        tokens.append(SyntaxToken(range: range, kind: kind))
                        covered.insert(integersIn: range.location..<(range.location + range.length))
                        break
                    }
                }
            }
        }

        for rule in rules {
            rule.regex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
                guard let match else { return }
                let range = match.range(at: rule.group)
                guard range.location != NSNotFound, range.length > 0 else { return }
                let indices = range.location..<(range.location + range.length)
                guard !covered.intersects(integersIn: indices) else { return }
                tokens.append(SyntaxToken(range: range, kind: rule.kind))
                covered.insert(integersIn: indices)
            }
        }

        return tokens.sorted { $0.range.location < $1.range.location }
    }

    // MARK: - Pattern assembly

    /// Group number of the wrapper around each span in `joinAlternatives`.
    static func wrapperGroupNumbers(_ spans: [SyntaxRule]) -> [Int] {
        var numbers: [Int] = []
        var next = 1
        for rule in spans {
            numbers.append(next)
            next += 1 + captureGroupCount(in: rule.pattern)
        }
        return numbers
    }

    /// Joins span rules into one alternation, wrapping each in a capture group
    /// and shifting its numeric backreferences to account for earlier groups.
    static func joinAlternatives(_ spans: [SyntaxRule]) -> String {
        var parts: [String] = []
        var next = 1
        for rule in spans {
            let shifted = shiftBackreferences(in: rule.pattern, by: next)
            let body = rule.options.contains(.anchorsMatchLines) ? "(?m:\(shifted))" : shifted
            parts.append("(\(body))")
            next += 1 + captureGroupCount(in: rule.pattern)
        }
        return parts.joined(separator: "|")
    }

    /// Number of capturing groups in `pattern` (ignores `(?…)` and escaped parens).
    static func captureGroupCount(in pattern: String) -> Int {
        var count = 0
        var escaped = false
        var inClass = false
        let chars = Array(pattern)
        for (i, char) in chars.enumerated() {
            if escaped { escaped = false; continue }
            switch char {
            case "\\": escaped = true
            case "[": inClass = true
            case "]": inClass = false
            case "(" where !inClass:
                if i + 1 < chars.count, chars[i + 1] == "?" { continue }
                count += 1
            default: break
            }
        }
        return count
    }

    /// Rewrites `\1`…`\9` to account for `offset` groups before this pattern
    /// (the pattern's own wrapper group is group `offset`).
    static func shiftBackreferences(in pattern: String, by offset: Int) -> String {
        var result = ""
        var escaped = false
        for char in pattern {
            if escaped {
                if let digit = char.wholeNumberValue, digit > 0 {
                    result += "\(digit + offset)"
                } else {
                    result.append(char)
                }
                escaped = false
            } else if char == "\\" {
                result.append(char)
                escaped = true
            } else {
                result.append(char)
            }
        }
        return result
    }

    static func wordAlternation(_ words: [String]) -> String {
        let escaped = words
            .sorted { $0.count > $1.count }
            .map { NSRegularExpression.escapedPattern(for: $0) }
        // Words may start or end with non-word characters ($true, defined?, .PHONY).
        return #"(?<![\w$.])(?:"# + escaped.joined(separator: "|") + #")(?![\w$])"#
    }
}
