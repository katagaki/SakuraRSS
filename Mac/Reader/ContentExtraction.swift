import Foundation
import Hanami
import Observation

/// Runs Hanami's shared `ContentResolver`, so the Mac reads content the same
/// way iOS does.
@Observable
final class ContentExtraction {

    private(set) var blocks: [IdentifiedContentBlock] = []
    private(set) var isExtracting = false
    private(set) var isPaywalled = false
    private(set) var author: String?
    private(set) var publishedDate: Date?

    func extract(article: Article, feed: Feed?) async {
        isExtracting = true
        defer { isExtracting = false }
        let result = await ContentResolver(article: article, feed: feed).extract()
        guard !Task.isCancelled else { return }
        isPaywalled = result.paywalled
        author = result.metadata.author
        publishedDate = result.metadata.publishedDate
        let text = result.text ?? article.content ?? article.summary ?? ""
        blocks = text.isEmpty ? [] : ContentBlock.cachedIdentifiedBlocks(text)
    }
}
