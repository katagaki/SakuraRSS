import EnhancedNavigation
import SwiftUI
import Hanami

/// The wide omnibox's field, with hardware keyboard selection of the
/// suggestions shown in its popup.
struct BrowserOmniboxEditingField: View {

    @Environment(FeedManager.self) private var feedManager
    @Environment(BrowserTabStore.self) private var store
    @Environment(BrowserOmniboxModel.self) private var omnibox
    @Environment(\.browserAddFeedAction) private var addFeed
    @Environment(\.browserOmniboxSubmit) private var submitOmnibox
    @FocusState private var isFieldFocused: Bool

    private var actions: BrowserOmniboxActions {
        BrowserOmniboxActions(store: store, omnibox: omnibox, addFeed: addFeed)
    }

    private var suggestions: [BrowserSuggestion] {
        BrowserSuggestionResolver(feedManager: feedManager)
            .suggestions(for: omnibox.text, contentMatches: omnibox.contentMatches)
    }

    var body: some View {
        BrowserOmniboxField(model: omnibox, onSubmit: submit, isFocused: $isFieldFocused)
            .onKeyPress(.downArrow) { moveSelection(forward: true) }
            .onKeyPress(.upArrow) { moveSelection(forward: false) }
            .onChange(of: omnibox.text) { omnibox.selectedSuggestionID = nil }
    }

    private func submit() {
        if let suggestion = suggestions.first(where: { $0.id == omnibox.selectedSuggestionID }) {
            actions.apply(suggestion)
        } else {
            isFieldFocused = false
            submitOmnibox?()
        }
    }

    private func moveSelection(forward: Bool) -> KeyPress.Result {
        guard !omnibox.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .ignored
        }
        let suggestions = suggestions
        guard !suggestions.isEmpty else { return .ignored }
        if let selectedIndex = suggestions.firstIndex(where: { $0.id == omnibox.selectedSuggestionID }) {
            let nextIndex = min(suggestions.count - 1, max(0, selectedIndex + (forward ? 1 : -1)))
            omnibox.selectedSuggestionID = suggestions[nextIndex].id
        } else {
            omnibox.selectedSuggestionID = forward ? suggestions.first?.id : suggestions.last?.id
        }
        return .handled
    }
}
