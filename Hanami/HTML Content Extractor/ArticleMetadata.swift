import Foundation

/// Structured metadata extracted from an article page.  Used to back-fill
/// feed-supplied fields when the RSS/Atom entry is sparse.
public nonisolated struct ArticleMetadata {
    public var author: String?
    public var publishedDate: Date?
    public var leadImageURL: String?
    public var pageTitle: String?

    public init(
        author: String? = nil,
        publishedDate: Date? = nil,
        leadImageURL: String? = nil,
        pageTitle: String? = nil
    ) {
        self.author = author
        self.publishedDate = publishedDate
        self.leadImageURL = leadImageURL
        self.pageTitle = pageTitle
    }
}
