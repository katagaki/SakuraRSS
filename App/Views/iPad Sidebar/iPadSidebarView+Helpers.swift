import SwiftUI

extension IPadSidebarView {

    var availableSections: [FeedSection] {
        let excluded: Set<FeedSection> = [.feeds, .podcasts, .youtube]
        return FeedSection.allCases.filter { !excluded.contains($0) && feedManager.hasFeeds(for: $0) }
    }

    var searchResults: [Article] {
        guard !searchText.isEmpty else { return [] }
        return (try? DatabaseManager.shared.searchArticles(query: searchText)) ?? []
    }

    func sectionIcon(_ section: FeedSection) -> String {
        switch section {
        case .feeds: "newspaper"
        case .podcasts: "headphones"
        case .instagram: "photo.on.rectangle"
        case .bluesky, .fediverse, .note, .reddit, .x: "person.2"
        case .substack: "envelope"
        case .vimeo, .youtube, .niconico: "play.rectangle"
        }
    }
}
