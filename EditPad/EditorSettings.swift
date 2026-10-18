import SwiftUI
import EditPadKit

/// UserDefaults keys and defaults for editor preferences, shared by
/// `@AppStorage` properties across views.
enum EditorSettings {
    static let fontSizeKey = "editor.fontSize"
    static let monospacedKey = "editor.monospaced"
    static let autocorrectKey = "editor.autocorrect"
    static let spellCheckKey = "editor.spellCheck"
    static let showStatusBarKey = "editor.showStatusBar"
    static let syntaxHighlightingKey = "editor.syntaxHighlighting"
    static let keyboardBarKey = "editor.keyboardBar"
    static let indentStyleKey = "editor.indentStyle"
    static let autoIndentKey = "editor.autoIndent"

    static let defaultFontSize: Double = 15
    static let fontSizeRange: ClosedRange<Double> = 10...36
    static let defaultIndentStyle = IndentStyle.fourSpaces

    /// Files larger than this (UTF-16 units) are shown without highlighting
    /// so typing stays responsive.
    static let highlightingLimit = 250_000

    static func font(size: Double, monospaced: Bool) -> Font {
        .system(size: size, design: monospaced ? .monospaced : .default)
    }

    static func uiFont(size: Double, monospaced: Bool) -> UIFont {
        monospaced
            ? .monospacedSystemFont(ofSize: size, weight: .regular)
            : .systemFont(ofSize: size)
    }
}
