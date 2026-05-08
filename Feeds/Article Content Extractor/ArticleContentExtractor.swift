import Foundation

/// Higher-level orchestrator that turns an `Article` into body text.
@MainActor
final class ArticleContentExtractor {

    /// Bumped whenever extraction logic changes.
    /// Invalidates all cached article content on next launch.
    nonisolated static let parserVersion = 18

    let article: Article
    let articleSourceOverride: ArticleSource?

    var result = ExtractionResult()
    var contentURL: URL?
    var isRedditLinkedArticle = false

    /// Wrapped twice so the cache distinguishes "not yet looked up"
    /// (`nil`) from "looked up and not found" (`.some(.none)`).
    private var resolvedFeed: Feed??

    init(
        article: Article,
        feed: Feed? = nil,
        articleSourceOverride: ArticleSource? = nil
    ) {
        self.article = article
        self.articleSourceOverride = articleSourceOverride
        self.contentURL = URL(string: article.url)
        if let feed {
            self.resolvedFeed = .some(.some(feed))
        }
    }

    /// Looks up the article's feed (preloaded if available, otherwise via
    /// the database). Cached after the first hit so repeat lookups in
    /// the cascade don't re-query.
    var feed: Feed? {
        if let resolvedFeed { return resolvedFeed }
        let lookup = try? DatabaseManager.shared.feed(byID: article.feedID)
        resolvedFeed = .some(lookup)
        return lookup
    }

    /// Resolves the active article source preference, honoring an
    /// explicit override (used by the Open Article extension) and
    /// otherwise falling back to the per-feed UserDefaults setting.
    var articleSource: ArticleSource {
        if let articleSourceOverride { return articleSourceOverride }
        let raw = UserDefaults.standard.string(forKey: "articleSource-\(article.feedID)")
        return raw.flatMap(ArticleSource.init(rawValue:)) ?? .automatic
    }
}
