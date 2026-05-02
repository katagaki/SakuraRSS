import Foundation

nonisolated struct Comment: Identifiable, Hashable, Sendable {
    let id: Int64
    let articleID: Int64
    var rank: Int
    var author: String
    var body: String
    var createdDate: Date?
    var sourceURL: String?

    /// Wraps a `FetchedComment` for in-memory display when caching is bypassed
    /// (e.g. ephemeral articles whose `id == 0` would collide in the DB).
    /// Negative IDs disambiguate display rows since DB rows use positive IDs.
    static func fromFetched(_ fetched: FetchedComment, rank: Int = 0) -> Comment {
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
