import SwiftUI
import UniformTypeIdentifiers
import EditPadKit

/// A plain-text file. Text is kept `\n`-normalized while editing; the file's
/// original encoding, BOM and line endings are restored on save.
struct TextDocument: FileDocument {
    var text: String
    var format: TextFormat

    init(text: String = "", format: TextFormat = .default) {
        self.text = text
        self.format = format
    }

    /// New documents are created as `.txt` (the first type). Text, source code,
    /// config files and files with unknown extensions can all be opened; see
    /// `scripts/generate-file-types.py`.
    static var readableContentTypes: [UTType] { SupportedFileTypes.readable }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        do {
            let decoded = try TextCodec.decode(data)
            self.init(text: decoded.text, format: decoded.format)
        } catch {
            // Binary files (images, archives) reach here via the `.data` catch-all.
            throw CocoaError(.fileReadUnknownStringEncoding, userInfo: [
                NSLocalizedDescriptionKey: "This file isn't text, so EditPad can't open it.",
            ])
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoded = TextCodec.encode(text, format: format)
        return FileWrapper(regularFileWithContents: encoded.data)
    }
}
