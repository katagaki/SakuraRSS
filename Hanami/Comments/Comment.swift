import Foundation

public nonisolated struct Comment: Identifiable, Hashable, Sendable {
    public let id: Int64
    public let articleID: Int64
    public var rank: Int
    public var author: String
    public var body: String
    public var createdDate: Date?
    public var sourceURL: String?

    /// Wraps a `FetchedComment` for in-memory display when caching is bypassed
    /// (e.g. ephemeral articles whose `id == 0` would collide in the DB).
    /// Negative IDs disambiguate display rows since DB rows use positive IDs.
    public static func fromFetched(_ fetched: FetchedComment, rank: Int = 0) -> Comment {
        Comment(
            id: Int64(-(rank + 1)),
            articleID: 0,
            rank: rank,
            author: fetched.author,
            body: fetched.body,
            createdDate: fetched.createdDate,
            sourceURL: fetched.sourceURL
        )
    }
}
