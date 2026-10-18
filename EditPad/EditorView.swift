import SwiftUI
import EditPadKit

struct EditorView: View {
    @Binding var document: TextDocument

    @AppStorage(EditorSettings.fontSizeKey) private var fontSize = EditorSettings.defaultFontSize
    @AppStorage(EditorSettings.monospacedKey) private var monospaced = true
    @AppStorage(EditorSettings.autocorrectKey) private var autocorrect = false
    @AppStorage(EditorSettings.showStatusBarKey) private var showStatusBar = true

    @State private var isFindPresented = false
    @State private var isSettingsPresented = false

    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $document.text)
                .font(EditorSettings.font(size: fontSize, monospaced: monospaced))
                .autocorrectionDisabled(!autocorrect)
                .textInputAutocapitalization(autocorrect ? .sentences : .never)
                .findNavigator(isPresented: $isFindPresented)
                .padding(.horizontal, 4)

            if showStatusBar {
                Divider()
                StatusBar(text: document.text, format: document.format)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    isFindPresented.toggle()
                } label: {
                    Label("Find and Replace", systemImage: "magnifyingglass")
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

                Toggle(isOn: $monospaced) {
                    Label("Monospaced", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }

            Section {
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
                Toggle(isOn: $showStatusBar) {
                    Label("Status Bar", systemImage: "rectangle.bottomthird.inset.filled")
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
}

#Preview {
    NavigationStack {
        EditorView(document: .constant(TextDocument(text: "Hello, EditPad!\nA lightweight text editor.")))
    }
}
