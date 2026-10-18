import SwiftUI
import UIKit
import EditPadKit

/// Everything about the editor's behavior that can change while it is on screen.
struct EditorConfiguration: Equatable {
    var language: SyntaxLanguage
    var fontSize: Double
    var monospaced: Bool
    var syntaxHighlighting: Bool
    var spellCheck: Bool
    var autocorrect: Bool
    var autoIndent: Bool
    var indentStyle: IndentStyle
    var keyboardBar: Bool
}

/// A `UITextView`-backed editor.
///
/// SwiftUI's `TextEditor` can't turn off spell checking, smart quotes or
/// inline predictions, and can't color text, so the editor wraps UIKit
/// directly. Text is synced to the binding on every edit; highlighting runs
/// on a background queue and is applied when the text hasn't changed since.
struct CodeTextView: UIViewRepresentable {
    @Binding var text: String
    var configuration: EditorConfiguration
    /// Set to `true` to open the find-and-replace bar; reset automatically.
    @Binding var findRequested: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .systemBackground
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 6, bottom: 10, right: 6)
        textView.isFindInteractionEnabled = true
        textView.dataDetectorTypes = []
        textView.smartInsertDeleteType = .no
        textView.adjustsFontForContentSizeCategory = false
        textView.accessibilityLabel = "Document text"

        let coordinator = context.coordinator
        coordinator.textView = textView
        coordinator.apply(configuration, force: true)
        textView.text = text
        coordinator.scheduleHighlight(after: 0)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        if textView.text != text {
            coordinator.replaceAllText(with: text)
        }
        coordinator.apply(configuration, force: false)

        if findRequested {
            textView.findInteraction?.presentFindNavigator(showingReplace: true)
            DispatchQueue.main.async { findRequested = false }
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: CodeTextView
        weak var textView: UITextView?

        private var configuration: EditorConfiguration?
        private var baseAttributes: [NSAttributedString.Key: Any] = [:]
        private var boldFont = UIFont.systemFont(ofSize: 15, weight: .semibold)
        private var isApplyingEdit = false

        private var pendingHighlight: DispatchWorkItem?
        private var highlightGeneration = 0
        private let highlightQueue = DispatchQueue(label: "EditPad.syntax-highlighting", qos: .userInitiated)
        /// Only touched on `highlightQueue`.
        private var highlighters: [SyntaxLanguage: SyntaxHighlighter] = [:]

        private lazy var keyboardBar = KeyboardBar(coordinator: self)

        init(parent: CodeTextView) {
            self.parent = parent
        }

        // MARK: Configuration

        func apply(_ new: EditorConfiguration, force: Bool) {
            guard let textView, force || new != configuration else { return }
            let old = configuration
            configuration = new

            if force || old?.fontSize != new.fontSize || old?.monospaced != new.monospaced {
                let font = EditorSettings.uiFont(size: new.fontSize, monospaced: new.monospaced)
                boldFont = UIFont(descriptor: font.fontDescriptor.withSymbolicTraits(.traitBold) ?? font.fontDescriptor,
                                  size: font.pointSize)
                let paragraph = NSMutableParagraphStyle()
                let spaceWidth = (" " as NSString).size(withAttributes: [.font: font]).width
                paragraph.defaultTabInterval = spaceWidth * 4
                paragraph.tabStops = []
                baseAttributes = [.font: font, .foregroundColor: UIColor.label, .paragraphStyle: paragraph]
                textView.font = font
                textView.textColor = .label
                textView.typingAttributes = baseAttributes
            }

            textView.spellCheckingType = new.spellCheck ? .yes : .no
            textView.autocorrectionType = new.autocorrect ? .yes : .no
            textView.autocapitalizationType = new.autocorrect ? .sentences : .none
            textView.smartQuotesType = new.autocorrect ? .yes : .no
            textView.smartDashesType = new.autocorrect ? .yes : .no
            textView.inlinePredictionType = new.autocorrect ? .yes : .no
            textView.inputAccessoryView = new.keyboardBar ? keyboardBar : nil

            let inputTraitsChanged = old?.spellCheck != new.spellCheck
                || old?.autocorrect != new.autocorrect
                || old?.keyboardBar != new.keyboardBar
            if !force, inputTraitsChanged, textView.isFirstResponder {
                textView.reloadInputViews()
            }

            if force || old?.language != new.language || old?.syntaxHighlighting != new.syntaxHighlighting
                || old?.fontSize != new.fontSize || old?.monospaced != new.monospaced {
                scheduleHighlight(after: 0)
            }
        }

        // MARK: Text sync

        func replaceAllText(with text: String) {
            guard let textView else { return }
            let selection = textView.selectedRange
            textView.text = text
            let length = (text as NSString).length
            let location = min(selection.location, length)
            textView.selectedRange = NSRange(location: location, length: min(selection.length, length - location))
            scheduleHighlight(after: 0)
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            scheduleHighlight(after: 0.12)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            // Typing after a colored token should start in the base style.
            textView.typingAttributes = baseAttributes
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard !isApplyingEdit, let configuration, textView.markedTextRange == nil else { return true }

            if text == "\n", configuration.autoIndent {
                let insertion = Indentation.newline(
                    in: textView.text, at: range.location,
                    style: configuration.indentStyle, language: configuration.language)
                if insertion != "\n" {
                    replace(range, with: insertion)
                    return false
                }
            } else if text == "\t", configuration.indentStyle != .tab {
                replace(range, with: configuration.indentStyle.unit)
                return false
            }
            return true
        }

        /// Replaces `range` through UITextInput so the edit is undoable.
        private func replace(_ range: NSRange, with string: String) {
            guard let textView,
                  let start = textView.position(from: textView.beginningOfDocument, offset: range.location),
                  let end = textView.position(from: start, offset: range.length),
                  let textRange = textView.textRange(from: start, to: end) else { return }
            isApplyingEdit = true
            textView.replace(textRange, withText: string)
            isApplyingEdit = false
            textViewDidChange(textView)
        }

        // MARK: Keyboard bar actions

        func insert(_ string: String) {
            guard let textView else { return }
            if string == "\t", let configuration {
                replace(textView.selectedRange, with: configuration.indentStyle.unit)
            } else {
                replace(textView.selectedRange, with: string)
            }
        }

        func undo() { textView?.undoManager?.undo() }
        func redo() { textView?.undoManager?.redo() }
        func dismissKeyboard() { textView?.resignFirstResponder() }

        // MARK: Highlighting

        func scheduleHighlight(after delay: TimeInterval) {
            pendingHighlight?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.highlightNow() }
            pendingHighlight = work
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }

        private func highlightNow() {
            guard let textView, let configuration else { return }
            highlightGeneration += 1
            let generation = highlightGeneration
            let snapshot = textView.text ?? ""
            let length = (snapshot as NSString).length

            guard configuration.syntaxHighlighting,
                  configuration.language != .plainText,
                  length <= EditorSettings.highlightingLimit else {
                apply(tokens: [], to: textView)
                return
            }

            let language = configuration.language
            highlightQueue.async { [weak self] in
                guard let self else { return }
                let highlighter = self.highlighter(for: language)
                let tokens = highlighter.tokens(in: snapshot)
                DispatchQueue.main.async { [weak self] in
                    guard let self, let textView = self.textView,
                          generation == self.highlightGeneration,
                          textView.text == snapshot else { return }
                    self.apply(tokens: tokens, to: textView)
                }
            }
        }

        /// Call only on `highlightQueue`.
        private func highlighter(for language: SyntaxLanguage) -> SyntaxHighlighter {
            if let cached = highlighters[language] { return cached }
            let created = SyntaxHighlighter(language: language)
            highlighters[language] = created
            return created
        }

        private func apply(tokens: [SyntaxToken], to textView: UITextView) {
            // Re-styling during IME composition would cancel the composition.
            guard textView.markedTextRange == nil else {
                scheduleHighlight(after: 0.3)
                return
            }
            let storage = textView.textStorage
            let fullRange = NSRange(location: 0, length: storage.length)
            storage.beginEditing()
            storage.setAttributes(baseAttributes, range: fullRange)
            for token in tokens where NSMaxRange(token.range) <= storage.length {
                storage.addAttribute(.foregroundColor, value: SyntaxTheme.color(for: token.kind), range: token.range)
                if SyntaxTheme.isBold(token.kind) {
                    storage.addAttribute(.font, value: boldFont, range: token.range)
                }
            }
            storage.endEditing()
            textView.typingAttributes = baseAttributes
        }
    }
}

// MARK: - Keyboard bar

/// A row of coding symbols above the keyboard, plus undo, redo and dismiss.
final class KeyboardBar: UIInputView {
    private weak var coordinator: CodeTextView.Coordinator?

    private static let symbols = ["⇥", "{", "}", "(", ")", "[", "]", "<", ">", "=", "\"", "'", ";", ":",
                                  "/", "\\", "|", "&", "!", "?", "#", "$", "@", "_", "-", "+", "*", "%",
                                  "^", "~", "`", ".", ","]

    init(coordinator: CodeTextView.Coordinator) {
        self.coordinator = coordinator
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 46), inputViewStyle: .keyboard)
        autoresizingMask = .flexibleWidth
        allowsSelfSizing = true
        build()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 46)
    }

    private func build() {
        let symbolStack = UIStackView()
        symbolStack.axis = .horizontal
        symbolStack.spacing = 6
        for symbol in Self.symbols {
            let insertion = symbol == "⇥" ? "\t" : symbol
            let label = symbol == "⇥" ? "Insert indent" : "Insert \(symbol)"
            symbolStack.addArrangedSubview(makeKey(title: symbol, accessibilityLabel: label) { [weak self] in
                self?.coordinator?.insert(insertion)
            })
        }

        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.alwaysBounceHorizontal = true
        scroll.addSubview(symbolStack)
        symbolStack.translatesAutoresizingMaskIntoConstraints = false

        let actions = UIStackView(arrangedSubviews: [
            makeKey(symbol: "arrow.uturn.backward", accessibilityLabel: "Undo") { [weak self] in self?.coordinator?.undo() },
            makeKey(symbol: "arrow.uturn.forward", accessibilityLabel: "Redo") { [weak self] in self?.coordinator?.redo() },
            makeKey(symbol: "keyboard.chevron.compact.down", accessibilityLabel: "Hide keyboard") { [weak self] in
                self?.coordinator?.dismissKeyboard()
            },
        ])
        actions.axis = .horizontal
        actions.spacing = 4

        let divider = UIView()
        divider.backgroundColor = .separator

        for view in [scroll, divider, actions] as [UIView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }

        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            scroll.trailingAnchor.constraint(equalTo: divider.leadingAnchor, constant: -4),

            symbolStack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 8),
            symbolStack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -8),
            symbolStack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 5),
            symbolStack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -5),
            symbolStack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor, constant: -10),

            divider.widthAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
            divider.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            divider.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            divider.trailingAnchor.constraint(equalTo: actions.leadingAnchor, constant: -4),

            actions.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -6),
            actions.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            actions.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5),
        ])
    }

    private func makeKey(title: String? = nil, symbol: String? = nil, accessibilityLabel: String,
                         action: @escaping () -> Void) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = .secondarySystemBackground
        config.baseForegroundColor = .label
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
        if let title {
            var attributed = AttributedString(title)
            attributed.font = .monospacedSystemFont(ofSize: 17, weight: .regular)
            config.attributedTitle = attributed
        }
        if let symbol {
            config.image = UIImage(systemName: symbol)
            config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        }
        let button = UIButton(configuration: config, primaryAction: UIAction { _ in
            UIDevice.current.playInputClick()
            action()
        })
        button.accessibilityLabel = accessibilityLabel
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 36).isActive = true
        return button
    }
}

extension KeyboardBar: UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}
