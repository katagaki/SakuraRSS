import EnhancedNavigation
import SwiftUI
import Hanami

/// What the wide omnibox's field and popup do with a choice.
@MainActor
struct BrowserOmniboxActions {

    let store: BrowserTabStore
    let omnibox: BrowserOmniboxModel
    let addFeed: ((String) -> Void)?

    func dismiss() {
        withAnimation(BrowserOmniboxModel.transition) { omnibox.deactivate() }
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
}
