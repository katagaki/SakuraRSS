import Hanami
import SwiftUI

struct YouTubeVideoDetails: View {

    let article: Article
    let feed: Feed?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(article.displayTitle)
                .font(.title2)
                .fontWeight(.bold)
                .textSelection(.enabled)
            HStack(spacing: 6) {
                if let feed {
                    Text(feed.title)
                }
                if let publishedDate = article.publishedDate {
                    Text(verbatim: "·")
                    Text(publishedDate, format: .dateTime.day().month().year())
                }
            }
            .foregroundStyle(.secondary)
            if let summary = article.summary, article.hasMeaningfulSummary {
                Divider()
                Text(SummaryPreview.text(for: summary))
                    .textSelection(.enabled)
            }
        }
    }
}
