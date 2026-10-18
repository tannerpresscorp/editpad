import Foundation

/// What a highlighted range represents. The app maps each kind to a color.
public enum SyntaxTokenKind: String, CaseIterable, Sendable {
    case keyword, literal, string, comment, number, type, attribute, function, property, tag
    case heading, emphasis, link
}

/// One regular-expression rule. `group` selects the capture group to color (0 = whole match).
struct SyntaxRule {
    var pattern: String
    var kind: SyntaxTokenKind
    var group: Int = 0
    var options: NSRegularExpression.Options = []
}

/// Highlighting rules for one language.
///
/// Highlighting runs in two passes. `spans` (comments, strings) are combined
/// into one ordered alternation so that whichever starts first wins, which
/// keeps keywords inside strings and quotes inside comments uncolored. The
/// remaining rules then color everything outside those spans.
struct SyntaxGrammar {
    var spans: [SyntaxRule] = []
    /// Extra pass-two rules, applied before keywords.
    var rules: [SyntaxRule] = []
    var keywords: [String] = []
    var literals: [String] = []
    var caseInsensitiveKeywords = false
    /// Color capitalized identifiers as types.
    var highlightsTypes = false
    /// Color `name(` as a function call.
    var highlightsCalls = false
    var highlightsNumbers = true
}

// MARK: - Shared patterns

enum Patterns {
    static let blockComment = SyntaxRule(pattern: #"/\*[\s\S]*?(?:\*/|\z)"#, kind: .comment)
    static let slashComment = SyntaxRule(pattern: #"//[^\n]*"#, kind: .comment)
    static let hashComment = SyntaxRule(pattern: #"#[^\n]*"#, kind: .comment)
    static let doubleQuoted = SyntaxRule(pattern: #""(?:[^"\\\n]|\\.)*"?"#, kind: .string)
    static let singleQuoted = SyntaxRule(pattern: #"'(?:[^'\\\n]|\\.)*'?"#, kind: .string)
    static let charLiteral = SyntaxRule(pattern: #"'(?:\\[^'\n]{1,10}|[^'\\\n])'"#, kind: .string)
    static let backtickString = SyntaxRule(pattern: #"`(?:[^`\\]|\\[\s\S])*`?"#, kind: .string)
    static let tripleDouble = SyntaxRule(pattern: #""""[\s\S]*?(?:"""|\z)"#, kind: .string)
    static let tripleSingle = SyntaxRule(pattern: #"'''[\s\S]*?(?:'''|\z)"#, kind: .string)

    static let annotation = SyntaxRule(pattern: #"@[A-Za-z_][\w.]*"#, kind: .attribute)
    static let preprocessor = SyntaxRule(pattern: #"^[ \t]*#[ \t]*[A-Za-z_]+"#, kind: .attribute, options: .anchorsMatchLines)
    static let number = #"\b(?:0[xX][0-9a-fA-F_]+|0[bB][01_]+|0[oO][0-7_]+|\d[\d_]*(?:\.\d[\d_]*)?(?:[eE][+-]?\d+)?)[a-zA-Z]*\b"#
    static let type = #"\b[A-Z][A-Za-z0-9_]*\b"#
    static let call = #"\b[a-zA-Z_][A-Za-z0-9_]*(?=\s*\()"#

    static let cFamilyKeywords = [
        "auto", "break", "case", "char", "const", "continue", "default", "do", "double", "else", "enum",
        "extern", "float", "for", "goto", "if", "inline", "int", "long", "register", "restrict", "return",
        "short", "signed", "sizeof", "static", "struct", "switch", "typedef", "union", "unsigned", "void",
        "volatile", "while", "_Bool", "bool",
    ]
}

// MARK: - Grammars

extension SyntaxGrammar {
    static func make(for language: SyntaxLanguage) -> SyntaxGrammar? {
        switch language {
        case .plainText:
            return nil

        case .c, .cpp, .objectiveC:
            var keywords = Patterns.cFamilyKeywords
            if language != .c {
                keywords += ["class", "namespace", "template", "typename", "public", "private", "protected",
                             "virtual", "override", "final", "new", "delete", "this", "using", "try", "catch",
                             "throw", "operator", "friend", "constexpr", "noexcept", "decltype", "explicit",
                             "mutable", "static_cast", "dynamic_cast", "reinterpret_cast", "const_cast", "auto"]
            }
            if language == .objectiveC {
                keywords += ["self", "super", "id", "instancetype", "nonatomic", "atomic", "strong", "weak",
                             "copy", "assign", "readonly", "readwrite", "nullable", "nonnull"]
            }
            return SyntaxGrammar(
                spans: [Patterns.blockComment, Patterns.slashComment, Patterns.doubleQuoted, Patterns.charLiteral],
                rules: [Patterns.preprocessor, Patterns.annotation],
                keywords: keywords,
                literals: ["true", "false", "NULL", "nullptr", "nil", "YES", "NO"],
                highlightsTypes: true, highlightsCalls: true)

        case .csharp, .java, .kotlin, .scala, .dart:
            let keywords: [String]
            switch language {
            case .csharp:
                keywords = ["abstract", "as", "async", "await", "base", "bool", "break", "byte", "case", "catch",
                            "char", "class", "const", "continue", "decimal", "default", "delegate", "do", "double",
                            "else", "enum", "event", "explicit", "extern", "finally", "fixed", "float", "for",
                            "foreach", "get", "if", "implicit", "in", "init", "int", "interface", "internal", "is",
                            "lock", "long", "namespace", "new", "object", "operator", "out", "override", "params",
                            "private", "protected", "public", "readonly", "record", "ref", "return", "sealed", "set",
                            "short", "static", "string", "struct", "switch", "this", "throw", "try", "typeof",
                            "uint", "ulong", "using", "var", "virtual", "void", "while", "yield"]
            case .kotlin:
                keywords = ["abstract", "as", "break", "by", "catch", "class", "companion", "const", "constructor",
                            "continue", "data", "do", "else", "enum", "finally", "for", "fun", "get", "if", "import",
                            "in", "init", "inline", "interface", "internal", "is", "lateinit", "object", "open",
                            "operator", "out", "override", "package", "private", "protected", "public", "return",
                            "sealed", "set", "super", "suspend", "this", "throw", "try", "typealias", "val", "var",
                            "vararg", "when", "where", "while"]
            case .scala:
                keywords = ["abstract", "case", "catch", "class", "def", "do", "else", "extends", "final",
                            "finally", "for", "given", "if", "implicit", "import", "lazy", "match", "new", "object",
                            "override", "package", "private", "protected", "return", "sealed", "super", "then",
                            "this", "throw", "trait", "try", "type", "using", "val", "var", "while", "with", "yield"]
            case .dart:
                keywords = ["abstract", "as", "async", "await", "break", "case", "catch", "class", "const",
                            "continue", "default", "do", "dynamic", "else", "enum", "export", "extends", "extension",
                            "factory", "final", "finally", "for", "get", "if", "implements", "import", "in", "is",
                            "late", "library", "mixin", "new", "operator", "part", "required", "return", "set",
                            "static", "super", "switch", "this", "throw", "try", "typedef", "var", "void", "while",
                            "with", "yield"]
            default:
                keywords = ["abstract", "assert", "boolean", "break", "byte", "case", "catch", "char", "class",
                            "const", "continue", "default", "do", "double", "else", "enum", "extends", "final",
                            "finally", "float", "for", "if", "implements", "import", "instanceof", "int",
                            "interface", "long", "native", "new", "package", "private", "protected", "public",
                            "record", "return", "sealed", "short", "static", "super", "switch", "synchronized",
                            "this", "throw", "throws", "transient", "try", "var", "void", "volatile", "while",
                            "def", "yield"]
            }
            var spans = [Patterns.blockComment, Patterns.slashComment]
            if language == .kotlin || language == .scala || language == .dart || language == .csharp {
                spans.append(Patterns.tripleDouble)
            }
            spans.append(Patterns.doubleQuoted)
            spans.append(language == .dart ? Patterns.singleQuoted : Patterns.charLiteral)
            var rules = [Patterns.annotation]
            if language == .csharp {
                rules.append(Patterns.preprocessor)
            }
            return SyntaxGrammar(
                spans: spans, rules: rules, keywords: keywords,
                literals: ["true", "false", "null"],
                highlightsTypes: true, highlightsCalls: true)

        case .swift:
            return SyntaxGrammar(
                spans: [Patterns.blockComment, Patterns.slashComment, Patterns.tripleDouble, Patterns.doubleQuoted],
                rules: [Patterns.annotation, SyntaxRule(pattern: #"#[A-Za-z_]\w*"#, kind: .attribute)],
                keywords: ["actor", "any", "as", "associatedtype", "async", "await", "break", "case", "catch",
                           "class", "continue", "convenience", "default", "defer", "deinit", "didSet", "do",
                           "dynamic", "else", "enum", "extension", "fallthrough", "fileprivate", "final", "for",
                           "func", "get", "guard", "if", "import", "in", "indirect", "init", "inout", "internal",
                           "is", "isolated", "lazy", "let", "macro", "mutating", "nonisolated", "nonmutating",
                           "open", "operator", "optional", "override", "package", "precedencegroup", "private",
                           "protocol", "public", "repeat", "required", "rethrows", "return", "set", "some",
                           "static", "struct", "subscript", "super", "switch", "throw", "throws", "try",
                           "typealias", "unowned", "var", "weak", "where", "while", "willSet", "Self", "self"],
                literals: ["true", "false", "nil"],
                highlightsTypes: true, highlightsCalls: true)

        case .go:
            return SyntaxGrammar(
                spans: [Patterns.blockComment, Patterns.slashComment, Patterns.doubleQuoted,
                        Patterns.backtickString, Patterns.charLiteral],
                keywords: ["break", "case", "chan", "const", "continue", "default", "defer", "else",
                           "fallthrough", "for", "func", "go", "goto", "if", "import", "interface", "map",
                           "package", "range", "return", "select", "struct", "switch", "type", "var",
                           "bool", "byte", "complex64", "complex128", "error", "float32", "float64", "int",
                           "int8", "int16", "int32", "int64", "rune", "string", "uint", "uint8", "uint16",
                           "uint32", "uint64", "uintptr", "any"],
                literals: ["true", "false", "nil", "iota"],
                highlightsTypes: true, highlightsCalls: true)

        case .rust:
            return SyntaxGrammar(
                spans: [Patterns.blockComment, Patterns.slashComment, Patterns.doubleQuoted, Patterns.charLiteral],
                rules: [SyntaxRule(pattern: #"#!?\[[^\]\n]*\]"#, kind: .attribute),
                        SyntaxRule(pattern: #"\b[a-z_][a-z0-9_]*!"#, kind: .function)],
                keywords: ["as", "async", "await", "break", "const", "continue", "crate", "dyn", "else", "enum",
                           "extern", "fn", "for", "if", "impl", "in", "let", "loop", "match", "mod", "move", "mut",
                           "pub", "ref", "return", "self", "Self", "static", "struct", "super", "trait", "type",
                           "unsafe", "use", "where", "while", "i8", "i16", "i32", "i64", "i128", "isize", "u8",
                           "u16", "u32", "u64", "u128", "usize", "f32", "f64", "bool", "char", "str"],
                literals: ["true", "false", "None", "Some", "Ok", "Err"],
                highlightsTypes: true, highlightsCalls: true)

        case .javascript, .typescript:
            var keywords = ["async", "await", "break", "case", "catch", "class", "const", "continue", "debugger",
                            "default", "delete", "do", "else", "export", "extends", "finally", "for", "from",
                            "function", "get", "if", "import", "in", "instanceof", "let", "new", "of", "return",
                            "set", "static", "super", "switch", "this", "throw", "try", "typeof", "var", "void",
                            "while", "with", "yield"]
            if language == .typescript {
                keywords += ["abstract", "any", "as", "boolean", "declare", "enum", "implements", "interface",
                             "is", "keyof", "namespace", "never", "number", "private", "protected", "public",
                             "readonly", "satisfies", "string", "type", "unknown"]
            }
            return SyntaxGrammar(
                spans: [Patterns.blockComment, Patterns.slashComment, Patterns.doubleQuoted,
                        Patterns.singleQuoted, Patterns.backtickString],
                rules: [Patterns.annotation],
                keywords: keywords,
                literals: ["true", "false", "null", "undefined", "NaN", "Infinity"],
                highlightsTypes: true, highlightsCalls: true)

        case .python:
            let prefix = #"(?:[rRbBuUfF]{1,2})?"#
            return SyntaxGrammar(
                spans: [Patterns.hashComment,
                        SyntaxRule(pattern: prefix + #""""[\s\S]*?(?:"""|\z)"#, kind: .string),
                        SyntaxRule(pattern: prefix + #"'''[\s\S]*?(?:'''|\z)"#, kind: .string),
                        SyntaxRule(pattern: prefix + #""(?:[^"\\\n]|\\.)*"?"#, kind: .string),
                        SyntaxRule(pattern: prefix + #"'(?:[^'\\\n]|\\.)*'?"#, kind: .string)],
                rules: [SyntaxRule(pattern: #"^[ \t]*@[\w.]+"#, kind: .attribute, options: .anchorsMatchLines)],
                keywords: ["and", "as", "assert", "async", "await", "break", "case", "class", "continue", "def",
                           "del", "elif", "else", "except", "finally", "for", "from", "global", "if", "import",
                           "in", "is", "lambda", "match", "nonlocal", "not", "or", "pass", "raise", "return",
                           "try", "while", "with", "yield", "self", "cls"],
                literals: ["True", "False", "None"],
                highlightsTypes: true, highlightsCalls: true)

        case .ruby:
            return SyntaxGrammar(
                spans: [SyntaxRule(pattern: #"^=begin[\s\S]*?(?:^=end|\z)"#, kind: .comment, options: .anchorsMatchLines),
                        Patterns.hashComment, Patterns.doubleQuoted, Patterns.singleQuoted],
                rules: [SyntaxRule(pattern: #"(?<![:\w]):[A-Za-z_]\w*[?!]?"#, kind: .literal),
                        SyntaxRule(pattern: #"@{1,2}[A-Za-z_]\w*"#, kind: .property)],
                keywords: ["alias", "and", "begin", "break", "case", "class", "def", "defined?", "do", "else",
                           "elsif", "end", "ensure", "for", "if", "in", "module", "next", "not", "or", "redo",
                           "rescue", "retry", "return", "self", "super", "then", "undef", "unless", "until",
                           "when", "while", "yield", "require", "require_relative", "attr_accessor",
                           "attr_reader", "attr_writer", "private", "protected", "public"],
                literals: ["true", "false", "nil"],
                highlightsTypes: true)

        case .php:
            return SyntaxGrammar(
                spans: [Patterns.blockComment, Patterns.slashComment, Patterns.hashComment,
                        Patterns.doubleQuoted, Patterns.singleQuoted],
                rules: [SyntaxRule(pattern: #"\$[A-Za-z_]\w*"#, kind: .property),
                        SyntaxRule(pattern: #"<\?php|\?>"#, kind: .tag)],
                keywords: ["abstract", "and", "array", "as", "break", "case", "catch", "class", "clone", "const",
                           "continue", "declare", "default", "do", "echo", "else", "elseif", "enum", "extends",
                           "final", "finally", "fn", "for", "foreach", "function", "global", "if", "implements",
                           "include", "include_once", "instanceof", "interface", "isset", "list", "match",
                           "namespace", "new", "or", "print", "private", "protected", "public", "readonly",
                           "require", "require_once", "return", "static", "switch", "throw", "trait", "try",
                           "unset", "use", "var", "while", "yield"],
                literals: ["true", "false", "null", "TRUE", "FALSE", "NULL"],
                caseInsensitiveKeywords: false,
                highlightsTypes: true, highlightsCalls: true)

        case .lua:
            return SyntaxGrammar(
                spans: [SyntaxRule(pattern: #"--\[(=*)\[[\s\S]*?(?:\]\1\]|\z)"#, kind: .comment),
                        SyntaxRule(pattern: #"--[^\n]*"#, kind: .comment),
                        SyntaxRule(pattern: #"\[(=*)\[[\s\S]*?(?:\]\2\]|\z)"#, kind: .string),
                        Patterns.doubleQuoted, Patterns.singleQuoted],
                keywords: ["and", "break", "do", "else", "elseif", "end", "for", "function", "goto", "if", "in",
                           "local", "not", "or", "repeat", "return", "then", "until", "while"],
                literals: ["true", "false", "nil"],
                highlightsCalls: true)

        case .perl:
            return SyntaxGrammar(
                spans: [Patterns.hashComment, Patterns.doubleQuoted, Patterns.singleQuoted],
                rules: [SyntaxRule(pattern: #"[$@%][A-Za-z_]\w*"#, kind: .property)],
                keywords: ["my", "our", "local", "sub", "if", "elsif", "else", "unless", "while", "until", "for",
                           "foreach", "last", "next", "redo", "return", "use", "no", "require", "package",
                           "print", "printf", "die", "eval", "do", "and", "or", "not", "eq", "ne", "lt", "gt"],
                literals: ["undef"],
                highlightsCalls: true)

        case .shell:
            return SyntaxGrammar(
                spans: [SyntaxRule(pattern: #"(?<![\w$#{])#[^\n]*"#, kind: .comment),
                        Patterns.doubleQuoted,
                        SyntaxRule(pattern: #"'[^']*'?"#, kind: .string)],
                rules: [SyntaxRule(pattern: #"\$\{[^}\n]*\}|\$[A-Za-z_]\w*|\$[0-9#?@*$!-]"#, kind: .property),
                        SyntaxRule(pattern: #"(?<=\s|^)--?[A-Za-z][\w-]*"#, kind: .attribute, options: .anchorsMatchLines)],
                keywords: ["if", "then", "else", "elif", "fi", "case", "esac", "for", "while", "until", "do",
                           "done", "in", "function", "select", "return", "exit", "export", "local", "readonly",
                           "declare", "unset", "source", "alias", "set", "shift", "trap", "eval", "exec",
                           "echo", "printf", "cd", "test"],
                literals: ["true", "false"])

        case .powershell:
            return SyntaxGrammar(
                spans: [SyntaxRule(pattern: #"<#[\s\S]*?(?:#>|\z)"#, kind: .comment),
                        Patterns.hashComment, Patterns.doubleQuoted, SyntaxRule(pattern: #"'[^']*'?"#, kind: .string)],
                rules: [SyntaxRule(pattern: #"\$[A-Za-z_][\w:]*"#, kind: .property),
                        SyntaxRule(pattern: #"\b[A-Z][a-z]+-[A-Z][A-Za-z]+\b"#, kind: .function),
                        SyntaxRule(pattern: #"(?<=\s)-[A-Za-z]+"#, kind: .attribute)],
                keywords: ["begin", "break", "catch", "class", "continue", "data", "do", "dynamicparam", "else",
                           "elseif", "end", "exit", "filter", "finally", "for", "foreach", "from", "function",
                           "if", "in", "param", "process", "return", "switch", "throw", "trap", "try", "until",
                           "using", "while"],
                literals: ["$true", "$false", "$null"],
                caseInsensitiveKeywords: true)

        case .sql:
            return SyntaxGrammar(
                spans: [Patterns.blockComment, SyntaxRule(pattern: #"--[^\n]*"#, kind: .comment),
                        SyntaxRule(pattern: #"'(?:[^']|'')*'?"#, kind: .string),
                        SyntaxRule(pattern: #""[^"\n]*"?"#, kind: .property)],
                keywords: ["add", "all", "alter", "and", "as", "asc", "begin", "between", "by", "case", "check",
                           "column", "commit", "constraint", "create", "cross", "database", "default", "delete",
                           "desc", "distinct", "drop", "else", "end", "exists", "foreign", "from", "full",
                           "group", "having", "if", "in", "index", "inner", "insert", "into", "is", "join", "key",
                           "left", "like", "limit", "not", "offset", "on", "or", "order", "outer", "primary",
                           "references", "returning", "right", "rollback", "select", "set", "table", "then",
                           "transaction", "union", "unique", "update", "values", "view", "when", "where", "with",
                           "integer", "int", "bigint", "smallint", "text", "varchar", "char", "boolean", "date",
                           "timestamp", "real", "float", "numeric", "decimal", "serial", "blob"],
                literals: ["null", "true", "false"],
                caseInsensitiveKeywords: true,
                highlightsCalls: true)

        case .html, .xml:
            var spans = [SyntaxRule(pattern: #"<!--[\s\S]*?(?:-->|\z)"#, kind: .comment),
                         SyntaxRule(pattern: #"<!\[CDATA\[[\s\S]*?(?:\]\]>|\z)"#, kind: .string),
                         SyntaxRule(pattern: #"<[!?][^>\n]*>?"#, kind: .attribute)]
            if language == .html {
                spans.insert(SyntaxRule(pattern: #"(?<=<script>)[\s\S]*?(?=</script>)"#, kind: .string), at: 1)
            }
            return SyntaxGrammar(
                spans: spans,
                rules: [SyntaxRule(pattern: #"</?[A-Za-z][\w:.-]*"#, kind: .tag),
                        SyntaxRule(pattern: #"/?>"#, kind: .tag),
                        SyntaxRule(pattern: #"(?<=\s)[A-Za-z_:@][\w:.-]*(?=\s*=)"#, kind: .property),
                        SyntaxRule(pattern: #"=\s*("[^"]*"|'[^']*')"#, kind: .string, group: 1),
                        SyntaxRule(pattern: #"&[A-Za-z0-9#]+;"#, kind: .literal)],
                highlightsNumbers: false)

        case .css:
            return SyntaxGrammar(
                spans: [Patterns.blockComment, Patterns.slashComment, Patterns.doubleQuoted, Patterns.singleQuoted],
                rules: [SyntaxRule(pattern: #"@[\w-]+"#, kind: .keyword),
                        SyntaxRule(pattern: #"#[0-9a-fA-F]{3,8}\b"#, kind: .number),
                        SyntaxRule(pattern: #"(?<![\w-])-?\d*\.?\d+(?:px|em|rem|%|vh|vw|vmin|vmax|ch|ex|pt|cm|mm|in|s|ms|deg|rad|fr|dpi)?\b"#, kind: .number),
                        SyntaxRule(pattern: #"[\w-]+(?=\s*:[^:{;]*[;}\n])"#, kind: .property),
                        SyntaxRule(pattern: #"[.#][A-Za-z_][\w-]*"#, kind: .type),
                        SyntaxRule(pattern: #"::?[\w-]+"#, kind: .attribute),
                        SyntaxRule(pattern: #"!important"#, kind: .keyword),
                        SyntaxRule(pattern: #"\$[\w-]+|--[\w-]+"#, kind: .property)],
                highlightsCalls: true, highlightsNumbers: false)

        case .json:
            return SyntaxGrammar(
                spans: [Patterns.blockComment, Patterns.slashComment,
                        SyntaxRule(pattern: #""(?:[^"\\\n]|\\.)*"(?=\s*:)"#, kind: .property),
                        Patterns.doubleQuoted],
                literals: ["true", "false", "null"],
                highlightsNumbers: true)

        case .yaml:
            return SyntaxGrammar(
                spans: [SyntaxRule(pattern: #"(?:^|(?<=\s))#[^\n]*"#, kind: .comment, options: .anchorsMatchLines),
                        Patterns.doubleQuoted, SyntaxRule(pattern: #"'(?:[^']|'')*'?"#, kind: .string)],
                rules: [SyntaxRule(pattern: #"^[ \t]*(?:- +)?([^\s#:'"][^#:\n]*?)\s*:(?=\s|$)"#, kind: .property, group: 1, options: .anchorsMatchLines),
                        SyntaxRule(pattern: #"^(?:---|\.\.\.)\s*$"#, kind: .keyword, options: .anchorsMatchLines),
                        SyntaxRule(pattern: #"[&*][\w-]+"#, kind: .attribute),
                        SyntaxRule(pattern: #"![\w!/-]+"#, kind: .type)],
                literals: ["true", "false", "null", "yes", "no", "on", "off", "~"])

        case .toml, .ini:
            return SyntaxGrammar(
                spans: [SyntaxRule(pattern: #"(?:^|(?<=\s))[#;][^\n]*"#, kind: .comment, options: .anchorsMatchLines),
                        Patterns.tripleDouble, Patterns.tripleSingle, Patterns.doubleQuoted,
                        SyntaxRule(pattern: #"'[^'\n]*'?"#, kind: .string)],
                rules: [SyntaxRule(pattern: #"^[ \t]*\[\[?[^\]\n]+\]\]?"#, kind: .type, options: .anchorsMatchLines),
                        SyntaxRule(pattern: #"^[ \t]*([\w.\-"' ]+?)\s*(?==|:)"#, kind: .property, group: 1, options: .anchorsMatchLines),
                        SyntaxRule(pattern: #"\$\{[^}\n]*\}"#, kind: .attribute)],
                literals: ["true", "false"])

        case .markdown:
            return SyntaxGrammar(
                spans: [SyntaxRule(pattern: #"^[ \t]*(```|~~~)[\s\S]*?(?:^[ \t]*\1[ \t]*$|\z)"#, kind: .string, options: .anchorsMatchLines),
                        SyntaxRule(pattern: #"`[^`\n]+`"#, kind: .string),
                        SyntaxRule(pattern: #"<!--[\s\S]*?(?:-->|\z)"#, kind: .comment)],
                rules: [SyntaxRule(pattern: #"^#{1,6}[ \t].*$"#, kind: .heading, options: .anchorsMatchLines),
                        SyntaxRule(pattern: #"^.+\n(?:=+|-+)[ \t]*$"#, kind: .heading, options: .anchorsMatchLines),
                        SyntaxRule(pattern: #"!?\[[^\]\n]*\]\([^)\n]*\)"#, kind: .link),
                        SyntaxRule(pattern: #"<https?://[^>\s]+>"#, kind: .link),
                        SyntaxRule(pattern: #"(\*\*|__)(?=\S)[^\n]*?\S\1"#, kind: .emphasis),
                        SyntaxRule(pattern: #"(?<![*\w])([*_])(?=\S)[^*_\n]*?\S\1(?![*\w])"#, kind: .emphasis),
                        SyntaxRule(pattern: #"^[ \t]*(?:[-*+]|\d+[.)])(?=[ \t])"#, kind: .keyword, options: .anchorsMatchLines),
                        SyntaxRule(pattern: #"^[ \t]*>.*$"#, kind: .comment, options: .anchorsMatchLines)],
                highlightsNumbers: false)

        case .makefile:
            return SyntaxGrammar(
                spans: [Patterns.hashComment, Patterns.doubleQuoted, Patterns.singleQuoted],
                rules: [SyntaxRule(pattern: #"^[^\s:#=][^:#=\n]*(?=:(?!=))"#, kind: .type, options: .anchorsMatchLines),
                        SyntaxRule(pattern: #"\$[({][^)}\n]*[)}]|\$[@<^?*%+]"#, kind: .property),
                        SyntaxRule(pattern: #"^[ \t]*[\w.-]+(?=\s*[:+?]?=)"#, kind: .attribute, options: .anchorsMatchLines)],
                keywords: ["ifeq", "ifneq", "ifdef", "ifndef", "else", "endif", "include", "define", "endef",
                           "export", "override", "vpath", ".PHONY"],
                highlightsNumbers: false)

        case .dockerfile:
            return SyntaxGrammar(
                spans: [SyntaxRule(pattern: #"^[ \t]*#[^\n]*"#, kind: .comment, options: .anchorsMatchLines),
                        Patterns.doubleQuoted, Patterns.singleQuoted],
                rules: [SyntaxRule(pattern: #"^[ \t]*(?:FROM|RUN|CMD|LABEL|MAINTAINER|EXPOSE|ENV|ADD|COPY|ENTRYPOINT|VOLUME|USER|WORKDIR|ARG|ONBUILD|STOPSIGNAL|HEALTHCHECK|SHELL)\b"#,
                                   kind: .keyword, options: [.anchorsMatchLines, .caseInsensitive]),
                        SyntaxRule(pattern: #"\$\{[^}\n]*\}|\$[A-Za-z_]\w*"#, kind: .property),
                        SyntaxRule(pattern: #"(?<=\s)--[\w-]+"#, kind: .attribute),
                        SyntaxRule(pattern: #"\bAS\b"#, kind: .keyword, options: .caseInsensitive)])
        }
    }
}
