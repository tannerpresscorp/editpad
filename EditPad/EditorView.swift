import SwiftUI
import EditPadKit

struct EditorView: View {
    @Binding var document: TextDocument
    /// Location of the open file; `nil` for an unsaved new document.
    let fileURL: URL?

    @AppStorage(EditorSettings.fontSizeKey) private var fontSize = EditorSettings.defaultFontSize
    @AppStorage(EditorSettings.monospacedKey) private var monospaced = true
    @AppStorage(EditorSettings.spellCheckKey) private var spellCheck = false
    @AppStorage(EditorSettings.autocorrectKey) private var autocorrect = false
    @AppStorage(EditorSettings.showStatusBarKey) private var showStatusBar = true
    @AppStorage(EditorSettings.syntaxHighlightingKey) private var syntaxHighlighting = true
    @AppStorage(EditorSettings.keyboardBarKey) private var keyboardBar = true
    @AppStorage(EditorSettings.autoIndentKey) private var autoIndent = true
    @AppStorage(EditorSettings.indentStyleKey) private var indentStyle = EditorSettings.defaultIndentStyle

    /// Manual syntax choice for this window; `nil` means detect from the file.
    @State private var languageOverride: SyntaxLanguage?
    @State private var isFindRequested = false
    @State private var isSettingsPresented = false

    @Environment(\.openURL) private var openURL

    private var detectedLanguage: SyntaxLanguage {
        SyntaxLanguage.detect(fileName: fileURL?.lastPathComponent ?? "", firstLine: firstLine)
    }

    private var language: SyntaxLanguage {
        languageOverride ?? detectedLanguage
    }

    /// First line, checked for a `#!` shebang. Looks at a bounded prefix only.
    private var firstLine: String? {
        guard document.text.hasPrefix("#!") else { return nil }
        return String(document.text.prefix(200).prefix { $0 != "\n" })
    }

    private var configuration: EditorConfiguration {
        EditorConfiguration(
            language: language,
            fontSize: fontSize,
            monospaced: monospaced,
            syntaxHighlighting: syntaxHighlighting,
            spellCheck: spellCheck,
            autocorrect: autocorrect,
            autoIndent: autoIndent,
            indentStyle: indentStyle,
            keyboardBar: keyboardBar)
    }

    var body: some View {
        VStack(spacing: 0) {
            CodeTextView(text: $document.text, configuration: configuration, findRequested: $isFindRequested)

            if showStatusBar {
                Divider()
                StatusBar(text: document.text, format: document.format, language: language)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    isFindRequested = true
                } label: {
                    Label("Find and Replace", systemImage: "magnifyingglass")
                }
                .keyboardShortcut("f", modifiers: [.command, .option])

                if let fileURL {
                    ShareLink(item: fileURL) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }

                optionsMenu
            }
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
        }
    }

    private var optionsMenu: some View {
        Menu {
            Section {
                Picker(selection: $languageOverride) {
                    Text("Automatic (\(detectedLanguage.displayName))").tag(SyntaxLanguage?.none)
                    Divider()
                    ForEach(SyntaxLanguage.allCases) { language in
                        Text(language.displayName).tag(SyntaxLanguage?.some(language))
                    }
                } label: {
                    Label("Syntax: \(language.displayName)", systemImage: "curlybraces")
                }
                .pickerStyle(.menu)

                Picker(selection: $document.format.lineEnding) {
                    ForEach(LineEnding.allCases) { ending in
                        Text(ending.displayName).tag(ending)
                    }
                } label: {
                    Label("Line Endings", systemImage: "return")
                }
                .pickerStyle(.menu)

                Picker(selection: encodingBinding) {
                    ForEach(TextEncoding.allCases) { encoding in
                        Text(encoding.label).tag(encoding)
                    }
                } label: {
                    Label("Encoding", systemImage: "character.book.closed")
                }
                .pickerStyle(.menu)
            }

            Section {
                Button {
                    adjustFontSize(by: 1)
                } label: {
                    Label("Bigger Text", systemImage: "textformat.size.larger")
                }
                .keyboardShortcut("=", modifiers: .command)
                .disabled(fontSize >= EditorSettings.fontSizeRange.upperBound)

                Button {
                    adjustFontSize(by: -1)
                } label: {
                    Label("Smaller Text", systemImage: "textformat.size.smaller")
                }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(fontSize <= EditorSettings.fontSizeRange.lowerBound)

                Toggle(isOn: $spellCheck) {
                    Label("Spell Checking", systemImage: "textformat.abc.dottedunderline")
                }

                Toggle(isOn: $showStatusBar) {
                    Label("Status Bar", systemImage: "rectangle.bottomthird.inset.filled")
                }
            }

            Section {
                if let fileURL {
                    Button {
                        showInFiles(fileURL)
                    } label: {
                        Label("Show in Files", systemImage: "folder")
                    }
                }

                Button {
                    isSettingsPresented = true
                } label: {
                    Label("Settings…", systemImage: "gearshape")
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        } label: {
            Label("Options", systemImage: "ellipsis.circle")
        }
    }

    /// Changing encoding also drops the BOM when the new encoding has none.
    private var encodingBinding: Binding<TextEncoding> {
        Binding(
            get: { document.format.encoding },
            set: { newValue in
                document.format = TextFormat(
                    encoding: newValue,
                    lineEnding: document.format.lineEnding,
                    hasByteOrderMark: document.format.hasByteOrderMark
                )
            }
        )
    }

    private func adjustFontSize(by delta: Double) {
        let range = EditorSettings.fontSizeRange
        fontSize = min(max(fontSize + delta, range.lowerBound), range.upperBound)
    }

    /// Opens the Files app at the folder containing the document.
    private func showInFiles(_ url: URL) {
        var components = URLComponents()
        components.scheme = "shareddocuments"
        components.path = url.deletingLastPathComponent().path
        if let filesURL = components.url {
            openURL(filesURL)
        }
    }
}

#Preview {
    NavigationStack {
        EditorView(
            document: .constant(TextDocument(text: "import SwiftUI\n\n// A lightweight editor\nlet answer = 42\n")),
            fileURL: URL(fileURLWithPath: "/tmp/Example.swift"))
    }
}
