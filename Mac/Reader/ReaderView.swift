import Hanami
import SwiftUI

struct ReaderView: View {

    let article: Article
    let feed: Feed?
    let activity: BrowserPageActivity
    @State private var extraction = ContentExtraction()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ReaderHeader(
                    article: article,
                    feed: feed,
                    author: extraction.author,
                    publishedDate: extraction.publishedDate ?? article.publishedDate
                )
                if extraction.isExtracting && extraction.blocks.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    if extraction.isPaywalled || extraction.blocks.isEmpty {
                        OpenInBrowserButton(
                            url: URL(string: article.url),
                            titleKey: extraction.isPaywalled ? "Article.Paywall.Banner" : "Article.OpenInBrowser"
                        )
                    }
                    ForEach(extraction.blocks) { identified in
                        ContentBlockView(block: identified.block)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .task(id: article.id) {
            await extraction.extract(article: article, feed: feed)
        }
        .onChange(of: extraction.isExtracting, initial: true) { _, isExtracting in
            activity.isExtractingContent = isExtracting
        }
        .onDisappear {
            activity.isExtractingContent = false
        }
    }
}
