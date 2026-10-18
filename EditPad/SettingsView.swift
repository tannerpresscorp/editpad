import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(EditorSettings.fontSizeKey) private var fontSize = EditorSettings.defaultFontSize
    @AppStorage(EditorSettings.monospacedKey) private var monospaced = true
    @AppStorage(EditorSettings.autocorrectKey) private var autocorrect = false
    @AppStorage(EditorSettings.showStatusBarKey) private var showStatusBar = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $fontSize, in: EditorSettings.fontSizeRange, step: 1) {
                        LabeledContent("Font Size", value: "\(Int(fontSize)) pt")
                    }
                    Toggle("Monospaced Font", isOn: $monospaced)
                    Text("The quick brown fox jumps over the lazy dog.")
                        .font(EditorSettings.font(size: fontSize, monospaced: monospaced))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Font preview")
                } header: {
                    Text("Appearance")
                }

                Section {
                    Toggle("Autocorrect and Capitalization", isOn: $autocorrect)
                    Toggle("Show Status Bar", isOn: $showStatusBar)
                } header: {
                    Text("Editing")
                } footer: {
                    Text("Autocorrect is off by default so code and config files stay exactly as typed.")
                }

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
