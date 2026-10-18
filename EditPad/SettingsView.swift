import SwiftUI
import EditPadKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(EditorSettings.fontSizeKey) private var fontSize = EditorSettings.defaultFontSize
    @AppStorage(EditorSettings.monospacedKey) private var monospaced = true
    @AppStorage(EditorSettings.syntaxHighlightingKey) private var syntaxHighlighting = true
    @AppStorage(EditorSettings.spellCheckKey) private var spellCheck = false
    @AppStorage(EditorSettings.autocorrectKey) private var autocorrect = false
    @AppStorage(EditorSettings.autoIndentKey) private var autoIndent = true
    @AppStorage(EditorSettings.indentStyleKey) private var indentStyle = EditorSettings.defaultIndentStyle
    @AppStorage(EditorSettings.keyboardBarKey) private var keyboardBar = true
    @AppStorage(EditorSettings.showStatusBarKey) private var showStatusBar = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $fontSize, in: EditorSettings.fontSizeRange, step: 1) {
                        LabeledContent("Font Size", value: "\(Int(fontSize)) pt")
                    }
                    Toggle("Monospaced Font", isOn: $monospaced)
                    Toggle("Syntax Highlighting", isOn: $syntaxHighlighting)
                    Text("func greet() { return \"Hello\" }")
                        .font(EditorSettings.font(size: fontSize, monospaced: monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .accessibilityLabel("Font preview")
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Highlighting covers about 30 languages and turns off automatically for files over 250 KB.")
                }

                Section {
                    Toggle("Spell Checking", isOn: $spellCheck)
                    Toggle("Autocorrect and Smart Punctuation", isOn: $autocorrect)
                } header: {
                    Text("Typing")
                } footer: {
                    Text("Both are off by default so code stays exactly as typed: no red underlines, curly quotes, em dashes or predictive text.")
                }

                Section {
                    Toggle("Auto-Indent", isOn: $autoIndent)
                    Picker("Tab Key Inserts", selection: $indentStyle) {
                        ForEach(IndentStyle.allCases) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    Toggle("Coding Keyboard Bar", isOn: $keyboardBar)
                    Toggle("Show Status Bar", isOn: $showStatusBar)
                } header: {
                    Text("Code")
                } footer: {
                    Text("The coding bar adds brackets, operators, a Tab key, undo and redo above the keyboard.")
                }

                Section {
                    Label("Open files from the Files app, or tap a file and choose Share › EditPad.", systemImage: "folder")
                    Label("Files you create here appear in Files under On My iPhone › EditPad.", systemImage: "iphone")
                } header: {
                    Text("Files")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Section {
                    LabeledContent("Version", value: Self.versionString)
                } header: {
                    Text("About")
                } footer: {
                    Text("EditPad keeps each file's original encoding and line endings when it saves.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private static var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView()
}
