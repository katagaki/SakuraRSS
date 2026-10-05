import Foundation
import Hanami

/// Turns what was typed into the address field into the feeds, lists, content
/// and actions shown beneath it.
struct AddressSuggestionResolver {

    private static let feedLimit = 5
    private static let listLimit = 3

    let feedManager: FeedManager

    func suggestions(for query: String, contentMatches: [Article]) -> [AddressSuggestion] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var results = [AddressSuggestion(
            kind: .searchContent(trimmed),
            section: .actions,
            title: String(localized: "Suggestions.SearchFor \(trimmed)", table: "Browser"),
            subtitle: nil,
            symbolName: "magnifyingglass"
        )]
        if let urlString = BrowserAddressInput.normalizedURLString(from: trimmed) {
            let display = BrowserAddressInput.displayString(for: urlString)
            results.append(AddressSuggestion(
                kind: .discoverFeeds(urlString),
                section: .actions,
                title: String(localized: "Suggestions.FindFeeds \(display)", table: "Browser"),
                subtitle: nil,
                symbolName: "antenna.radiowaves.left.and.right"
            ))
        }
        let needle = trimmed.lowercased()
        results += feedManager.feeds
            .filter { $0.title.lowercased().contains(needle) || $0.domain.lowercased().contains(needle) }
            .prefix(Self.feedLimit)
            .map { feed in
                AddressSuggestion(
                    kind: .location(.feed(feed.id)), section: .feeds, title: feed.title,
                    subtitle: feed.domain, symbolName: BrowserLocation.feed(feed.id).symbolName(in: feedManager)
                )
            }
        results += feedManager.lists
            .filter { $0.name.lowercased().contains(needle) }
            .prefix(Self.listLimit)
            .map { place(.list($0.id), section: .lists) }
        results += contentMatches.map { article in
            AddressSuggestion(
                kind: .location(.article(article.id)), section: .content, title: article.displayTitle,
                subtitle: feedManager.feedsByID[article.feedID]?.title, symbolName: "doc.text"
            )
        }
        return results
    }

    private func place(_ location: BrowserLocation, section: AddressSuggestion.Section) -> AddressSuggestion {
        AddressSuggestion(
            kind: .location(location),
            section: section,
            title: location.title(in: feedManager),
            subtitle: nil,
            symbolName: location.symbolName(in: feedManager)
        )
    }
}
