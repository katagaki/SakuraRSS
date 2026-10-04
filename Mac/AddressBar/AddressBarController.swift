import AppKit
import Hanami

final class AddressBarController: NSObject, NSTextFieldDelegate {

    let field = AddressField()
    let feedManager: FeedManager
    var onCommit: ((AddressSuggestion.Kind) -> Void)?
    private let suggestionsPanel = SuggestionsPanelController()
    private var displayedTitle = ""
    private var contentMatches: [Article] = []
    private var contentSearchTask: Task<Void, Never>?

    init(feedManager: FeedManager) {
        self.feedManager = feedManager
        super.init()
        field.placeholderString = String(localized: "AddressField.Prompt", table: "Browser")
        field.bezelStyle = .roundedBezel
        field.alignment = .center
        field.lineBreakMode = .byTruncatingTail
        field.usesSingleLineMode = true
        field.delegate = self
        field.onFocus = { [weak self] in
            self?.beginEditing()
        }
        suggestionsPanel.onCommit = { [weak self] suggestion in
            self?.commit(suggestion.kind)
        }
    }

    func display(_ location: BrowserLocation) {
        displayedTitle = location.title(in: feedManager)
        if field.currentEditor() == nil {
            field.stringValue = displayedTitle
        }
    }

    func focus() {
        field.window?.makeFirstResponder(field)
    }

    private func beginEditing() {
        field.alignment = .natural
        contentMatches = []
        DispatchQueue.main.async { [weak self] in
            // The field editor is already set up by now, so the field's own
            // alignment change doesn't reach it.
            guard let editor = self?.field.currentEditor() as? NSTextView else { return }
            editor.alignment = .natural
            editor.selectAll(nil)
        }
        showSuggestions()
    }

    func controlTextDidChange(_ notification: Notification) {
        contentMatches = []
        showSuggestions()
        searchContent(matching: field.stringValue)
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        endEditing()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.moveDown(_:)):
            suggestionsPanel.moveSelection(by: 1)
        case #selector(NSResponder.moveUp(_:)):
            suggestionsPanel.moveSelection(by: -1)
        case #selector(NSResponder.insertNewline(_:)):
            commitSelection()
        case #selector(NSResponder.cancelOperation(_:)):
            field.window?.makeFirstResponder(nil)
        default:
            return false
        }
        return true
    }

    private func showSuggestions() {
        let suggestions = AddressSuggestionResolver(feedManager: feedManager)
            .suggestions(for: field.stringValue, contentMatches: contentMatches)
        suggestionsPanel.show(suggestions, below: field)
    }

    private func searchContent(matching query: String) {
        contentSearchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return }
        contentSearchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            let matches = await Task.detached {
                Array(((try? DatabaseManager.shared.searchArticles(query: trimmed)) ?? []).prefix(5))
            }.value
            guard let self, !Task.isCancelled, self.field.currentEditor() != nil else { return }
            self.contentMatches = matches
            self.showSuggestions()
        }
    }

    private func commitSelection() {
        if let suggestion = suggestionsPanel.selectedSuggestion {
            commit(suggestion.kind)
        } else {
            let trimmed = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            commit(.searchContent(trimmed))
        }
    }

    private func commit(_ kind: AddressSuggestion.Kind) {
        field.window?.makeFirstResponder(nil)
        endEditing()
        onCommit?(kind)
    }

    private func endEditing() {
        contentSearchTask?.cancel()
        suggestionsPanel.hide()
        field.alignment = .center
        field.stringValue = displayedTitle
    }
}
