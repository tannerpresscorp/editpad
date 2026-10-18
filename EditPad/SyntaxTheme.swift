import UIKit
import EditPadKit

/// Colors for syntax tokens, adapting to light and dark mode.
enum SyntaxTheme {
    static func color(for kind: SyntaxTokenKind) -> UIColor {
        switch kind {
        case .keyword: return dynamic(light: 0xAD3DA4, dark: 0xFF7AB2)
        case .literal: return dynamic(light: 0xAD3DA4, dark: 0xFF7AB2)
        case .string: return dynamic(light: 0xC41A16, dark: 0xFF8170)
        case .comment: return dynamic(light: 0x5D6C79, dark: 0x7F8C98)
        case .number: return dynamic(light: 0x272AD8, dark: 0xD9C97C)
        case .type: return dynamic(light: 0x0B4F79, dark: 0x6BDFFF)
        case .attribute: return dynamic(light: 0x815F03, dark: 0xCC9768)
        case .function: return dynamic(light: 0x326D74, dark: 0x67B7A4)
        case .property: return dynamic(light: 0x3E6D74, dark: 0x4EB0CC)
        case .tag: return dynamic(light: 0x1C00CF, dark: 0x5DD8FF)
        case .heading: return dynamic(light: 0x1C00CF, dark: 0x5DD8FF)
        case .emphasis: return dynamic(light: 0x7D3C98, dark: 0xD0A8FF)
        case .link: return dynamic(light: 0x0E7C86, dark: 0x41A1C0)
        }
    }

    /// Token kinds drawn in bold.
    static func isBold(_ kind: SyntaxTokenKind) -> Bool {
        kind == .heading
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { traits in
            rgb(traits.userInterfaceStyle == .dark ? dark : light)
        }
    }

    private static func rgb(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1)
    }
}
