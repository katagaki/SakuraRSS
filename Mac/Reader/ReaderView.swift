import Hanami
import SwiftUI

struct ReaderView: View {

    let article: Article
    let feed: Feed?
    let activity: BrowserPageActivity
    let feedManager: FeedManager
    let actions: TodayActions?
    let isPreview: Bool
    let articleSource: ArticleSource?
    @State private var extraction = ContentExtraction()
    @State private var assistant: ContentAssistant

    init(
        article: Article,
        feed: Feed?,
        activity: BrowserPageActivity,
        feedManager: FeedManager,
        actions: TodayActions? = nil,
        articleSource: ArticleSource? = nil,
        isPreview: Bool = false
    ) {
        self.article = article
        self.feed = feed
        self.activity = activity
        self.feedManager = feedManager
        self.actions = actions
        self.isPreview = isPreview
        self.articleSource = articleSource
        _assistant = State(initialValue: ContentAssistant(article: article, translatesTitle: true))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ReaderHeader(
                    title: assistant.displayTitle(original: article.displayTitle),
                    feed: feed,
                    author: extraction.author,
                    publishedDate: extraction.publishedDate ?? article.publishedDate
                )
                if extraction.text != nil && !isPreview {
                    ContentAssistBar(assistant: assistant, source: extraction.text)
                }
                content
                if !isPreview {
                    ReaderInsightsSection(article: article, feedManager: feedManager, actions: actions)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .task(id: article.id) {
            await assistant.loadCached()
            await extraction.extract(article: article, feed: feed, articleSource: articleSource)
        }
        .onChange(of: extraction.isExtracting || assistant.isWorking, initial: true) { _, isBusy in
            activity.isExtractingContent = isBusy
        }
        .onDisappear {
            activity.isExtractingContent = false
        }
    }

    @ViewBuilder
    private var content: some View {
        if extraction.isExtracting && extraction.text == nil {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else {
            if extraction.isPaywalled || extraction.text == nil {
                OpenInBrowserButton(
                    url: URL(string: article.url),
                    titleKey: extraction.isPaywalled ? "Article.Paywall.Banner" : "Article.OpenInBrowser"
                )
            }
            if let displayText = assistant.displayText(original: extraction.text) {
                // Lazy so selecting content lays out only the blocks on screen,
                // not the whole text, as it's arrowed through.
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(ContentBlock.cachedIdentifiedBlocks(displayText)) { identified in
                        ContentBlockView(block: identified.block)
                    }
                }
                .id("\(assistant.showingSummary)-\(assistant.showingTranslation)")
            }
        }
    }
}
