import Foundation

/// A single comment fetched from a remote source, prior to persistence.
nonisolated struct FetchedComment: Sendable, Hashable {
    var author: String
    var body: String
    var createdDate: Date?
    var sourceURL: String?
}

/// A source that can supply a "top comments" preview for an article.
protocol CommentsProvider {

    nonisolated static var providerID: String { get }

    /// True if this source can produce comments for `article` in `feed`.
    nonisolated static func canProvideComments(for article: Article, in feed: Feed?) -> Bool

    /// The URL the user is sent to when they tap "Join the Conversation".
    nonisolated static func commentsURL(for article: Article, in feed: Feed?) -> URL?

    /// Fetches up to `limit` ranked comments for `article`.
    static func fetchComments(
        for article: Article, in feed: Feed?, limit: Int
    ) async throws -> [FetchedComment]
}
