import Foundation
import Hanami

/// Turns what the user typed into the omnibox into the mix of feeds, content
/// and actions Safari shows under its address field.
@MainActor
struct BrowserSuggestionResolver {

    private static let feedLimit = 5
    private static let listLimit = 3

    let feedManager: FeedManager

    func suggestions(for query: String, contentMatches: [Article]) -> [BrowserSuggestion] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return emptyQuerySuggestions() }

        var results: [BrowserSuggestion] = [
            BrowserSuggestion(
                id: "search:\(trimmed)",
                kind: .searchContent(trimmed),
                section: .actions
            )
        ]
        if let host = BrowserAddressInput.siteHost(from: trimmed) {
            results.append(BrowserSuggestion(
                id: "discover:\(host)",
                kind: .discoverFeeds(host),
                section: .actions
            ))
        }
        results += matchingFeeds(trimmed).map {
            BrowserSuggestion(id: "feed:\($0.id)", kind: .feed($0), section: .feeds)
        }
        results += matchingLists(trimmed).map {
            BrowserSuggestion(id: "list:\($0.id)", kind: .list($0), section: .lists)
        }
        results += contentMatches.map {
            BrowserSuggestion(id: "article:\($0.id)", kind: .article($0), section: .content)
        }
        return results
    }

    private func emptyQuerySuggestions() -> [BrowserSuggestion] {
        [BrowserLocation.startPage, .allContent, .bookmarks].map {
            BrowserSuggestion(id: "place:\($0.persistenceToken)", kind: .place($0), section: .places)
        }
    }

    private func matchingFeeds(_ query: String) -> [Feed] {
        let needle = query.lowercased()
        return feedManager.feeds
            .filter {
                $0.title.lowercased().contains(needle) || $0.domain.lowercased().contains(needle)
            }
            .prefix(BrowserSuggestionResolver.feedLimit)
            .map { $0 }
    }

    private func matchingLists(_ query: String) -> [FeedList] {
        let needle = query.lowercased()
        return feedManager.lists
            .filter { $0.name.lowercased().contains(needle) }
            .prefix(BrowserSuggestionResolver.listLimit)
            .map { $0 }
    }
}
