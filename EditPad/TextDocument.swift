import SwiftUI
import UniformTypeIdentifiers
import EditPadKit

extension UTType {
    /// Markdown, declared as an imported type in Info.plist.
    static let markdown = UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText)
}

/// A plain-text file. Text is kept `\n`-normalized while editing; the file's
/// original encoding, BOM and line endings are restored on save.
struct TextDocument: FileDocument {
    var text: String
    var format: TextFormat

    init(text: String = "", format: TextFormat = .default) {
        self.text = text
        self.format = format
    }

    /// New documents are created as `.txt`; anything plain-text can be opened.
    static var readableContentTypes: [UTType] {
        [.plainText, .utf8PlainText, .utf16PlainText, .markdown, .sourceCode, .json, .xml, .yaml,
         .commaSeparatedText, .tabSeparatedText, .log, .propertyList]
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        do {
            let decoded = try TextCodec.decode(data)
            self.init(text: decoded.text, format: decoded.format)
        } catch {
            throw CocoaError(.fileReadUnknownStringEncoding)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoded = TextCodec.encode(text, format: format)
        return FileWrapper(regularFileWithContents: encoded.data)
    }
}
