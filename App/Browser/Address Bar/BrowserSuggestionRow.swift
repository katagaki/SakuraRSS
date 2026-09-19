import SwiftUI
import Hanami

struct BrowserSuggestionRow: View {

    static let iconSize: CGFloat = 26

    @Environment(FeedManager.self) private var feedManager
    let suggestion: BrowserSuggestion
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                content
                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        switch suggestion.kind {
        case .place(let location):
            BrowserLocationLabel(
                description: BrowserLocationDescription.describe(location, feedManager: feedManager),
                iconSize: BrowserSuggestionRow.iconSize,
                titleFont: .body,
                subtitleFont: .caption
            )
        case .feed(let feed):
            BrowserLocationLabel(
                description: BrowserLocationDescription.describe(.feed(feed.id), feedManager: feedManager),
                iconSize: BrowserSuggestionRow.iconSize,
                titleFont: .body,
                subtitleFont: .caption
            )
        case .list(let list):
            BrowserLocationLabel(
                description: BrowserLocationDescription.describe(.list(list.id), feedManager: feedManager),
                iconSize: BrowserSuggestionRow.iconSize,
                titleFont: .body,
                subtitleFont: .caption
            )
        case .article(let article):
            articleLabel(article)
        case .searchContent(let query):
            actionLabel(
                title: String(localized: "Suggestions.SearchFor \(query)", table: "Browser"),
                symbolName: "magnifyingglass"
            )
        case .discoverFeeds(let host):
            actionLabel(
                title: String(localized: "Suggestions.FindFeeds \(host)", table: "Browser"),
                symbolName: "antenna.radiowaves.left.and.right"
            )
        }
    }

    private func articleLabel(_ article: Article) -> some View {
        let feed = feedManager.feed(forArticle: article)
        return BrowserLocationLabel(
            description: BrowserLocationDescription(
                title: article.title,
                subtitle: feed?.title,
                symbolName: "doc.text",
                feed: feed
            ),
            iconSize: BrowserSuggestionRow.iconSize,
            titleFont: .body,
            subtitleFont: .caption
        )
    }

    private func actionLabel(title: String, symbolName: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbolName)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(
                    width: BrowserSuggestionRow.iconSize,
                    height: BrowserSuggestionRow.iconSize
                )
            Text(title)
                .font(.body)
                .lineLimit(1)
        }
    }
}
