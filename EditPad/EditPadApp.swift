import SwiftUI

@main
struct EditPadApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: TextDocument()) { file in
            EditorView(document: file.$document)
        }
    }
}
