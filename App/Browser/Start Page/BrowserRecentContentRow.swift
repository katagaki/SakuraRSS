import SwiftUI
import Hanami

struct BrowserRecentContentRow: View {

    @Environment(FeedManager.self) private var feedManager
    let article: Article

    private var feed: Feed? {
        feedManager.feed(forArticle: article)
    }

    var body: some View {
        HStack(spacing: 12) {
            if let feed {
                FeedIcon(feed: feed, size: 34, cornerRadius: BrowserIconMetrics.cornerRadius(for: 34))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(article.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let feed {
                    Text(feed.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(.rect)
    }
}
