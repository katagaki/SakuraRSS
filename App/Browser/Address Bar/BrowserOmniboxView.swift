import SwiftUI
import Hanami

/// The suggestion overlay. The field itself lives in the bottom toolbar, so
/// this view only dims the page and lists what the text matches.
struct BrowserOmniboxView: View {

    private static let suggestionListMaxHeight: CGFloat = 340

    @Environment(FeedManager.self) private var feedManager
    @Environment(BrowserTabStore.self) private var store
    @Environment(BrowserOmniboxModel.self) private var omnibox
    @Environment(\.browserAddFeedAction) private var addFeed

    private var suggestions: [BrowserSuggestion] {
        BrowserSuggestionResolver(feedManager: feedManager)
            .suggestions(for: omnibox.text, contentMatches: omnibox.contentMatches)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .contentShape(.rect)
                .onTapGesture { omnibox.deactivate() }

            VStack(spacing: 0) {
                // The list only claims the room it needs, so the dimmed page
                // above it stays tappable the way Safari's does.
                Spacer(minLength: 0)
                suggestionList
                    .frame(maxHeight: BrowserOmniboxView.suggestionListMaxHeight)
            }
        }
        .task(id: omnibox.text) {
            await refreshContentMatches()
        }
    }

    private var suggestionList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(BrowserSuggestion.Section.allCases, id: \.rawValue) { section in
                    let sectionSuggestions = suggestions.filter { $0.section == section }
                    if !sectionSuggestions.isEmpty {
                        Text(section.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 6)
                        ForEach(sectionSuggestions) { suggestion in
                            BrowserSuggestionRow(suggestion: suggestion) {
                                apply(suggestion)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 9)
                        }
                    }
                }
            }
            .padding(.bottom, 12)
        }
        .compatibleInteractiveKeyboardDismissal()
        .defaultScrollAnchor(.bottom)
    }

    private func refreshContentMatches() async {
        let query = omnibox.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            omnibox.contentMatches = []
            return
        }
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }
        let found = (try? DatabaseManager.shared.searchArticles(query: query)) ?? []
        guard !Task.isCancelled else { return }
        omnibox.contentMatches = Array(found.prefix(4))
    }

    private func apply(_ suggestion: BrowserSuggestion) {
        switch suggestion.kind {
        case .place(let location):
            store.navigate(to: location)
        case .feed(let feed):
            store.navigate(to: .feed(feed.id))
        case .list(let list):
            store.navigate(to: .list(list.id))
        case .article(let article):
            store.push(article)
        case .searchContent(let query):
            store.navigate(to: .search(query))
        case .discoverFeeds(let host):
            addFeed?("https://\(host)")
        }
        omnibox.deactivate()
    }
}
