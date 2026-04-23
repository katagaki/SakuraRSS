import Foundation

/// Runs a `PetalRecipe` against its source page and emits `ParsedArticle` values.
nonisolated enum PetalEngine {

    struct PreviewResult: Sendable {
        var articles: [ParsedArticle]
        var fetchedHTMLSample: String?
        var errorMessage: String?
    }

    // MARK: - Public API

    /// Runs the recipe and returns matching items as `ParsedArticle`s.
    /// `pageURL` overrides `recipe.siteURL` for live builder previews.
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

    /// Runs the recipe and returns a preview with an HTML sample for selector debugging.
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
