import SwiftUI
import EditPadKit

/// Word, character and line counts plus the file's language and on-disk format.
struct StatusBar: View {
    let text: String
    let format: TextFormat
    let language: SyntaxLanguage

    var body: some View {
        let stats = TextStatistics(text)
        let fallsBack = !TextCodec.canEncode(text, as: format.encoding)

        HStack(spacing: 12) {
            Text(stats.summary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 8)

            Text(language.displayName)
                .lineLimit(1)

            Text(format.lineEnding.label)

            HStack(spacing: 2) {
                if fallsBack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                Text(format.encoding.label + (format.hasByteOrderMark ? " BOM" : ""))
            }
            .accessibilityElement(children: .combine)
            .accessibilityHint(fallsBack ? "Some characters can't be saved in this encoding, so the file will be saved as UTF-8." : "")
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}

#Preview {
    StatusBar(text: "Hello world\nSecond line", format: .default, language: .swift)
}
