import EnhancedNavigation
import SwiftUI
import Hanami

extension BrowserRegularOmnibox {

    func dismiss() {
        isFieldFocused = false
        withAnimation(BrowserOmniboxModel.transition) { omnibox.deactivate() }
    }

    func submit() {
        if let suggestion = suggestions.first(where: { $0.id == selectedSuggestionID }) {
            apply(suggestion)
        } else {
            isFieldFocused = false
            submitOmnibox?()
        }
    }

    func moveSelection(forward: Bool) -> KeyPress.Result {
        guard !omnibox.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .ignored
        }
        let suggestions = suggestions
        guard !suggestions.isEmpty else { return .ignored }
        if let selectedIndex = suggestions.firstIndex(where: { $0.id == selectedSuggestionID }) {
            let nextIndex = min(suggestions.count - 1, max(0, selectedIndex + (forward ? 1 : -1)))
            selectedSuggestionID = suggestions[nextIndex].id
        } else {
            selectedSuggestionID = forward ? suggestions.first?.id : suggestions.last?.id
        }
        return .handled
    }

    func refreshContentMatches() async {
        let query = omnibox.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard omnibox.isActive, query.count >= 2 else {
            omnibox.contentMatches = []
            return
        }
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }
        let found = (try? DatabaseManager.shared.searchArticles(query: query)) ?? []
        guard !Task.isCancelled else { return }
        omnibox.contentMatches = Array(found.prefix(4))
    }

    func open(_ location: BrowserLocation) {
        store.navigate(to: location)
        dismiss()
    }

    func apply(_ suggestion: BrowserSuggestion) {
        switch suggestion.kind {
        case .place(let location): store.navigate(to: location)
        case .feed(let feed): store.navigate(to: .feed(feed.id))
        case .list(let list): store.navigate(to: .list(list.id))
        case .article(let article): store.push(article)
        case .searchContent(let query): store.navigate(to: .search(query))
        case .discoverFeeds(let host): addFeed?("https://\(host)")
        }
        dismiss()
    }
}
