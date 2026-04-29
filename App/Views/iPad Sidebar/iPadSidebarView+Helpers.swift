import SwiftUI

extension IPadSidebarView {

    var availableSections: [FeedSection] {
        FeedSection.allCases.filter { $0 != .feeds && feedManager.hasFeeds(for: $0) }
    }

    var searchResults: [Article] {
        guard !searchText.isEmpty else { return [] }
        return (try? DatabaseManager.shared.searchArticles(query: searchText)) ?? []
    }

    func sectionIcon(_ section: FeedSection) -> String {
        switch section {
        case .feeds: "newspaper"
        case .podcasts: "headphones"
        case .instagram, .pixelfed: "photo.on.rectangle"
        case .bluesky, .mastodon, .note, .reddit, .x: "person.2"
        case .substack: "envelope"
        case .vimeo, .youtube, .niconico: "play.rectangle"
        }
    }
}
