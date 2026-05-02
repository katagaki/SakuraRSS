import Foundation

/// Routes an article + its feed to a `CommentSource`, when one exists.
nonisolated enum CommentSourceRegistry {

    static let all: [any CommentSource.Type] = [
        HackerNewsCommentsFetcher.self,
        RedditCommentsFetcher.self,
        XCommentsFetcher.self
    ]

    static func source(
        for article: Article, in feed: Feed?
    ) -> (any CommentSource.Type)? {
        all.first { $0.canProvideComments(for: article, in: feed) }
    }
}
