import Hanami
import SwiftUI

struct YouTubeVideoDetails: View {

    let article: Article
    let feed: Feed?
    @State private var assistant: ContentAssistant

    init(article: Article, feed: Feed?) {
        self.article = article
        self.feed = feed
        _assistant = State(initialValue: ContentAssistant(article: article, translatesTitle: false))
    }

    private var descriptionSource: String? {
        guard article.hasMeaningfulSummary, let source = article.summary ?? article.content, !source.isEmpty else {
            return nil
        }
        return source
    }

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
            if let descriptionSource {
                Divider()
                ContentAssistBar(assistant: assistant, source: descriptionSource)
                    .padding(.vertical, 4)
                description(source: descriptionSource)
            }
        }
        .task(id: article.id) { await assistant.loadCached() }
    }

    @ViewBuilder
    private func description(source: String) -> some View {
        if assistant.showingSummary || assistant.showingTranslation,
           let displayText = assistant.displayText(original: source) {
            Text(ContentBlock.plainText(from: displayText))
                .textSelection(.enabled)
        } else {
            Text(SummaryPreview.text(for: source))
                .textSelection(.enabled)
        }
    }
}
