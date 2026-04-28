import Foundation

/// Structured metadata extracted from an article page.  Used to back-fill
/// feed-supplied fields when the RSS/Atom entry is sparse.
nonisolated struct ArticleMetadata {
    var author: String?
    var publishedDate: Date?
    var leadImageURL: String?
    var pageTitle: String?
}
