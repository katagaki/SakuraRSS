import SwiftUI
import Hanami

/// The suggestion overlay. The field itself lives in the bottom toolbar, so
/// this view only dims the page and lists what the text matches.
struct BrowserOmniboxView: View {

    /// Raised alongside the body-size rows: at the old height the first
    /// section header was already scrolled out of view.
    private static let suggestionListMaxHeight: CGFloat = 420

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
                .onTapGesture {
                    withAnimation(BrowserOmniboxModel.transition) {
                        omnibox.deactivate()
                    }
                }

            VStack(spacing: 0) {
                // The list only claims the room it needs, so the dimmed page
                // above it stays tappable the way Safari's does.
                Spacer(minLength: 0)
                suggestionList
                    // Bottom aligned: a maxHeight frame centres its content,
                    // which left the rows floating in the middle of the box
                    // with a dead gap above the field.
                    .frame(
                        maxHeight: BrowserOmniboxView.suggestionListMaxHeight,
                        alignment: .bottom
                    )
            }
        }
        .task(id: omnibox.text) {
            await refreshContentMatches()
        }
    }

    private var suggestionList: some View {
        // Hugs its content when it is short, scrolls once it is not. A plain
        // ScrollView always claims its full height, which left a dead gap
        // between the last suggestion and the field.
        ViewThatFits(in: .vertical) {
            suggestionRows
            ScrollView {
                suggestionRows
            }
            .compatibleInteractiveKeyboardDismissal()
            .defaultScrollAnchor(.bottom)
        }
    }

    private var suggestionRows: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(BrowserSuggestion.Section.allCases, id: \.rawValue) { section in
                let sectionSuggestions = suggestions.filter { $0.section == section }
                if !sectionSuggestions.isEmpty {
                    Text(section.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 6)
                    ForEach(sectionSuggestions) { suggestion in
                        BrowserSuggestionRow(suggestion: suggestion) {
                            apply(suggestion)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 11)
                    }
                }
            }
        }
        .padding(.bottom, 12)
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
        withAnimation(BrowserOmniboxModel.transition) {
            omnibox.deactivate()
        }
    }
}
