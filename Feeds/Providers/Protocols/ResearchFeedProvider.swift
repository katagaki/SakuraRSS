import Foundation

/// A provider whose articles have an associated PDF download
protocol ResearchFeedProvider: FeedProvider {

    /// The PDF URL for the article at `articleURL`, or `nil` if the URL
    /// isn't a recognised piece of content for this provider.
    nonisolated static func pdfURL(forArticleURL articleURL: String) -> URL?
}
