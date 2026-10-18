import SwiftUI

/// UserDefaults keys and defaults for editor preferences, shared by
/// `@AppStorage` properties across views.
enum EditorSettings {
    static let fontSizeKey = "editor.fontSize"
    static let monospacedKey = "editor.monospaced"
    static let autocorrectKey = "editor.autocorrect"
    static let showStatusBarKey = "editor.showStatusBar"

    static let defaultFontSize: Double = 17
    static let fontSizeRange: ClosedRange<Double> = 10...36

    static func font(size: Double, monospaced: Bool) -> Font {
        .system(size: size, design: monospaced ? .monospaced : .default)
    }
}
