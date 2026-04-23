import Foundation

nonisolated struct ExtractionResult {
    var text: String?
    var metadata: ArticleMetadata
    var paywalled: Bool

    init(
        text: String? = nil,
        metadata: ArticleMetadata = ArticleMetadata(),
        paywalled: Bool = false
    ) {
        self.text = text
        self.metadata = metadata
        self.paywalled = paywalled
    }
}
