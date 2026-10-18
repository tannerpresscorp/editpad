import Foundation

/// Languages EditPad can highlight, detected from a file's name or first line.
public enum SyntaxLanguage: String, CaseIterable, Sendable, Identifiable {
    case plainText
    case c, cpp, objectiveC, csharp, java, kotlin, swift, go, rust, dart, scala
    case javascript, typescript, python, ruby, php, lua, perl, shell, powershell
    case sql, html, xml, css, json, yaml, toml, ini, markdown, makefile, dockerfile

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .plainText: return "Plain Text"
        case .c: return "C"
        case .cpp: return "C++"
        case .objectiveC: return "Objective-C"
        case .csharp: return "C#"
        case .java: return "Java"
        case .kotlin: return "Kotlin"
        case .swift: return "Swift"
        case .go: return "Go"
        case .rust: return "Rust"
        case .dart: return "Dart"
        case .scala: return "Scala"
        case .javascript: return "JavaScript"
        case .typescript: return "TypeScript"
        case .python: return "Python"
        case .ruby: return "Ruby"
        case .php: return "PHP"
        case .lua: return "Lua"
        case .perl: return "Perl"
        case .shell: return "Shell"
        case .powershell: return "PowerShell"
        case .sql: return "SQL"
        case .html: return "HTML"
        case .xml: return "XML"
        case .css: return "CSS"
        case .json: return "JSON"
        case .yaml: return "YAML"
        case .toml: return "TOML"
        case .ini: return "INI / Config"
        case .markdown: return "Markdown"
        case .makefile: return "Makefile"
        case .dockerfile: return "Dockerfile"
        }
    }

    /// Lower-cased file extension → language.
    public static let byExtension: [String: SyntaxLanguage] = {
        var map: [String: SyntaxLanguage] = [:]
        func add(_ language: SyntaxLanguage, _ extensions: String...) {
            for ext in extensions { map[ext] = language }
        }
        add(.c, "c", "h")
        add(.cpp, "cc", "cpp", "cxx", "c++", "hh", "hpp", "hxx", "h++", "ino")
        add(.objectiveC, "m", "mm")
        add(.csharp, "cs", "csx")
        add(.java, "java", "groovy", "gradle")
        add(.kotlin, "kt", "kts")
        add(.swift, "swift")
        add(.go, "go")
        add(.rust, "rs")
        add(.dart, "dart")
        add(.scala, "scala", "sc")
        add(.javascript, "js", "mjs", "cjs", "jsx")
        add(.typescript, "ts", "mts", "cts", "tsx")
        add(.python, "py", "pyw", "pyi")
        add(.ruby, "rb", "rake", "gemspec")
        add(.php, "php", "phtml")
        add(.lua, "lua")
        add(.perl, "pl", "pm")
        add(.shell, "sh", "bash", "zsh", "fish", "ksh", "command", "bashrc", "zshrc", "profile")
        add(.powershell, "ps1", "psm1", "psd1")
        add(.sql, "sql")
        add(.html, "html", "htm", "xhtml", "vue", "svelte")
        add(.xml, "xml", "plist", "svg", "xsd", "xsl", "storyboard", "xib", "csproj", "entitlements")
        add(.css, "css", "scss", "sass", "less")
        add(.json, "json", "jsonc", "json5", "geojson", "webmanifest")
        add(.yaml, "yml", "yaml")
        add(.toml, "toml")
        add(.ini, "ini", "cfg", "conf", "properties", "env", "editorconfig", "gitconfig", "gitignore", "gitattributes", "npmrc")
        add(.markdown, "md", "markdown", "mdown", "mkd")
        add(.makefile, "mk", "mak")
        add(.dockerfile, "dockerfile")
        return map
    }()

    /// Exact (lower-cased) file names → language, for files without a useful extension.
    public static let byFileName: [String: SyntaxLanguage] = [
        "makefile": .makefile, "gnumakefile": .makefile,
        "dockerfile": .dockerfile, "containerfile": .dockerfile,
        "gemfile": .ruby, "rakefile": .ruby, "podfile": .ruby, "fastfile": .ruby, "brewfile": .ruby,
        "package.swift": .swift,
        ".bashrc": .shell, ".zshrc": .shell, ".profile": .shell, ".bash_profile": .shell, ".zprofile": .shell,
        ".gitignore": .ini, ".gitattributes": .ini, ".gitconfig": .ini, ".editorconfig": .ini, ".env": .ini,
        ".npmrc": .ini, ".dockerignore": .ini,
    ]

    /// Detects the language of a file.
    ///
    /// Checks the exact file name, then the extension, then a `#!` shebang in
    /// `firstLine`. Falls back to `.plainText`.
    public static func detect(fileName: String, firstLine: String? = nil) -> SyntaxLanguage {
        let name = fileName.lowercased()
        if let match = byFileName[name] { return match }
        if name.hasPrefix(".env.") { return .ini }
        if name.hasPrefix("dockerfile.") || name.hasSuffix(".dockerfile") { return .dockerfile }

        if let dot = name.lastIndex(of: "."), dot != name.startIndex {
            let ext = String(name[name.index(after: dot)...])
            if let match = byExtension[ext] { return match }
        } else if name.hasPrefix("."), let match = byExtension[String(name.dropFirst())] {
            return match
        }

        if let firstLine, firstLine.hasPrefix("#!") {
            return detect(shebang: firstLine)
        }
        return .plainText
    }

    private static func detect(shebang line: String) -> SyntaxLanguage {
        let interpreters: [(String, SyntaxLanguage)] = [
            ("python", .python), ("node", .javascript), ("deno", .typescript), ("ruby", .ruby),
            ("perl", .perl), ("php", .php), ("lua", .lua), ("pwsh", .powershell), ("swift", .swift),
            ("bash", .shell), ("zsh", .shell), ("fish", .shell), ("/sh", .shell), (" sh", .shell),
        ]
        let lower = line.lowercased()
        for (needle, language) in interpreters where lower.contains(needle) {
            return language
        }
        return .shell
    }
}
