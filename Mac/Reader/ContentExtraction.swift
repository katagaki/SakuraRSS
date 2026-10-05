import Foundation
import Hanami
import Observation

/// Runs Hanami's shared `ContentResolver`, so the Mac reads content the same
/// way iOS does.
@Observable
final class ContentExtraction {

    private(set) var text: String?
    private(set) var isExtracting = false
    private(set) var isPaywalled = false
    private(set) var author: String?
    private(set) var publishedDate: Date?

    func extract(article: Article, feed: Feed?, articleSource: ArticleSource? = nil) async {
        isExtracting = true
        defer { isExtracting = false }
        let result = await ContentResolver(
            article: article, feed: feed, articleSourceOverride: articleSource
        ).extract()
        guard !Task.isCancelled else { return }
        isPaywalled = result.paywalled
        author = result.metadata.author
        publishedDate = result.metadata.publishedDate
        let resolved = result.text ?? article.content ?? article.summary ?? ""
        text = resolved.isEmpty ? nil : resolved
    }
}
