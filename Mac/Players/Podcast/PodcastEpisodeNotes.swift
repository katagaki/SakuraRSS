import Hanami
import SwiftUI

struct PodcastEpisodeNotes: View {

    let article: Article
    @State private var assistant: ContentAssistant

    init(article: Article) {
        self.article = article
        _assistant = State(initialValue: ContentAssistant(article: article, translatesTitle: false))
    }

    private var source: String? {
        guard let summary = article.summary, !summary.isEmpty else { return nil }
        return summary
    }

    var body: some View {
        if let source, let displayText = assistant.displayText(original: source) {
            VStack(alignment: .leading, spacing: 14) {
                Divider()
                ContentAssistBar(assistant: assistant, source: source)
                ForEach(ContentBlock.cachedIdentifiedBlocks(displayText)) { identified in
                    ContentBlockView(block: identified.block)
                }
                .id("\(assistant.showingSummary)-\(assistant.showingTranslation)")
            }
            .task(id: article.id) { await assistant.loadCached() }
        }
    }
}
