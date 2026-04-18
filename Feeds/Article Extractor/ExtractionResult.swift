import Foundation

/// Output of an article extraction.  `text` is the marker-laden
/// article body; `metadata` holds author / publish date / lead image
/// when discoverable.  `paywalled` flags recognized paywall gates.
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
