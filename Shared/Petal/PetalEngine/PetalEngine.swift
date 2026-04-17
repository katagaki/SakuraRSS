import Foundation

/// Runs a `PetalRecipe` against its source page and emits
/// `ParsedArticle` values the feed-refresh pipeline already knows
/// how to insert.
///
/// The engine intentionally re-uses `SwiftSoup` (already a dep for
/// `ArticleExtractor`) and the same `URLRequest.sakura(...)` helper
/// the rest of the app uses, so a Web Feed's network fingerprint
/// is indistinguishable from a normal RSS fetch.
///
/// `PetalEngine` is `nonisolated` so it can run from any actor.
/// The one exception is `fetchMode == .rendered`, which hops to
/// the main actor inside `PetalEngine+Fetching` to drive a
/// `WKWebView`.
///
/// Implementation lives across several files in this folder:
///   - `PetalEngine.swift` — this file: type, nested values,
///     and the two public entry points.
///   - `PetalEngine+Fetching.swift` — HTML retrieval (static
///     URLSession + rendered WKWebView).
///   - `PetalEngine+Parsing.swift` — SwiftSoup selector runner
///     and per-item extractors.
///   - `PetalEngine+Dates.swift` — flexible date parsing with
///     shared formatter caches.
nonisolated enum PetalEngine {

    struct PreviewResult: Sendable {
        var articles: [ParsedArticle]
        var fetchedHTMLSample: String?
        var errorMessage: String?
    }

    // MARK: - Public API

    /// Runs the recipe and returns matching items as
    /// `ParsedArticle`s.  `pageURL` overrides `recipe.siteURL`
    /// (used by the builder preview when the user is editing the
    /// source URL live).
    static func fetchArticles(
        for recipe: PetalRecipe,
        pageURL overrideURL: String? = nil
    ) async -> [ParsedArticle] {
        guard let html = await fetchHTML(for: recipe, pageURL: overrideURL),
              !html.isEmpty else {
            return []
        }
        return parse(html: html, recipe: recipe)
    }

    /// Runs the recipe and returns a preview payload with a
    /// small HTML sample the builder UI shows for debugging "why
    /// didn't my selector match?".
    static func preview(
        for recipe: PetalRecipe,
        pageURL overrideURL: String? = nil
    ) async -> PreviewResult {
        guard let html = await fetchHTML(for: recipe, pageURL: overrideURL) else {
            return PreviewResult(
                articles: [],
                fetchedHTMLSample: nil,
                errorMessage: String(localized: "Error.FetchFailed", table: "Petal")
            )
        }
        let articles = parse(html: html, recipe: recipe)
        return PreviewResult(
            articles: articles,
            fetchedHTMLSample: html,
            errorMessage: articles.isEmpty
                ? String(localized: "Error.NoMatches", table: "Petal") : nil
        )
    }
}
