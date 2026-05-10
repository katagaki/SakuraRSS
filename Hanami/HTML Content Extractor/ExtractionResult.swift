import Foundation

public nonisolated struct ExtractionResult {
    public var text: String?
    public var metadata: ArticleMetadata
    public var paywalled: Bool

    public init(
        text: String? = nil,
        metadata: ArticleMetadata = ArticleMetadata(),
        paywalled: Bool = false
    ) {
        self.text = text
        self.metadata = metadata
        self.paywalled = paywalled
    }
}
