import Foundation
import SwiftSoup

/// Runs a `PetalRecipe` against its source page and emits
/// `ParsedArticle` values the feed-refresh pipeline already knows
/// how to insert.
///
/// The engine intentionally re-uses `SwiftSoup` (already a dep for
/// `ArticleExtractor`) and the same `URLRequest.sakura(...)` helper
/// the rest of the app uses, so a Petal feed's network fingerprint
/// is indistinguishable from a normal RSS fetch.
///
/// The engine is `nonisolated` so it can run from any actor.  The
/// one exception is `fetchMode == .rendered`, which must hop to the
/// main actor to drive a `WKWebView`.
nonisolated enum PetalEngine {

    struct PreviewResult: Sendable {
        var articles: [ParsedArticle]
        var fetchedHTMLSample: String?
        var errorMessage: String?
    }

    /// Runs the recipe and returns matching items as `ParsedArticle`s.
    /// `pageURL` overrides `recipe.siteURL` (used by the builder
    /// preview when the user is editing the source URL live).
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

    /// Runs the recipe and returns a preview payload with a small
    /// HTML sample the builder UI shows for debugging "why didn't my
    /// selector match?".
    static func preview(
        for recipe: PetalRecipe,
        pageURL overrideURL: String? = nil
    ) async -> PreviewResult {
        guard let html = await fetchHTML(for: recipe, pageURL: overrideURL) else {
            return PreviewResult(
                articles: [],
                fetchedHTMLSample: nil,
                errorMessage: String(localized: "Petal.Error.FetchFailed")
            )
        }
        let articles = parse(html: html, recipe: recipe)
        return PreviewResult(
            articles: articles,
            fetchedHTMLSample: String(html.prefix(4000)),
            errorMessage: articles.isEmpty
                ? String(localized: "Petal.Error.NoMatches") : nil
        )
    }

    // MARK: - Fetching

    private static func fetchHTML(
        for recipe: PetalRecipe,
        pageURL overrideURL: String?
    ) async -> String? {
        let urlString = overrideURL?.isEmpty == false
            ? overrideURL! : recipe.siteURL
        guard let url = URL(string: urlString) else { return nil }

        switch recipe.fetchMode {
        case .staticHTML:
            return await fetchStaticHTML(from: url)
        case .rendered:
            return await fetchRenderedHTML(from: url)
        }
    }

    private static func fetchStaticHTML(from url: URL) async -> String? {
        do {
            let (data, response) = try await URLSession.shared.data(
                for: .sakura(url: url, timeoutInterval: 15)
            )
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                return nil
            }
            return String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1)
        } catch {
            return nil
        }
    }

    private static func fetchRenderedHTML(from url: URL) async -> String? {
        // The loader is `@MainActor` because `WKWebView` has to live
        // on the main thread.  Wrap construction + the (suspending)
        // `loadHTML` call in a single hop so the reference never
        // escapes the main actor.
        await Task { @MainActor in
            await PetalWebViewLoader().loadHTML(from: url)
        }.value
    }

    // MARK: - Parsing

    /// Runs the recipe's selectors against the given HTML.  Public
    /// so the builder can feed pre-fetched HTML in without re-fetching
    /// on every keystroke.
    static func parse(html: String, recipe: PetalRecipe) -> [ParsedArticle] {
        let base = URL(string: recipe.baseURL ?? recipe.siteURL)
        do {
            let document = try SwiftSoup.parse(html, recipe.siteURL)
            let items = try document.select(recipe.itemSelector)
            var articles: [ParsedArticle] = []
            articles.reserveCapacity(min(items.count, recipe.maxItems))
            var seenURLs = Set<String>()

            for item in items {
                guard articles.count < recipe.maxItems else { break }
                if let parsed = parseItem(item, recipe: recipe, baseURL: base),
                   seenURLs.insert(parsed.url).inserted {
                    articles.append(parsed)
                }
            }
            return articles
        } catch {
            return []
        }
    }

    private static func parseItem(
        _ item: Element,
        recipe: PetalRecipe,
        baseURL: URL?
    ) -> ParsedArticle? {
        // Link — required. Without a URL there's nothing to show.
        let linkString: String? = {
            if let selector = recipe.linkSelector,
               let element = try? item.select(selector).first(),
               let value = try? element.attr(recipe.linkAttribute),
               !value.isEmpty {
                return value
            }
            // Fall back to the first <a href> inside (or the item itself).
            if let anchor = try? item.select("a[href]").first(),
               let href = try? anchor.attr("href"), !href.isEmpty {
                return href
            }
            return nil
        }()
        guard let linkString,
              let resolvedURL = resolveURL(linkString, base: baseURL) else {
            return nil
        }

        let title = extractText(
            item: item, selector: recipe.titleSelector, fallbackOwnText: true
        )
        guard !title.isEmpty else { return nil }

        let summary = extractText(
            item: item, selector: recipe.summarySelector, fallbackOwnText: false
        )
        let author = extractText(
            item: item, selector: recipe.authorSelector, fallbackOwnText: false
        )
        let image = extractImage(item: item, recipe: recipe, baseURL: baseURL)
        let date = extractDate(item: item, recipe: recipe)

        return ParsedArticle(
            title: title,
            url: resolvedURL,
            author: author.isEmpty ? nil : author,
            summary: summary.isEmpty ? nil : summary,
            content: nil,
            imageURL: image,
            publishedDate: date,
            audioURL: nil,
            duration: nil
        )
    }

    private static func extractText(
        item: Element,
        selector: String?,
        fallbackOwnText: Bool
    ) -> String {
        if let selector, !selector.isEmpty,
           let element = try? item.select(selector).first() {
            if let text = try? element.text() {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if fallbackOwnText, let text = try? item.text() {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    private static func extractImage(
        item: Element,
        recipe: PetalRecipe,
        baseURL: URL?
    ) -> String? {
        if let selector = recipe.imageSelector, !selector.isEmpty,
           let element = try? item.select(selector).first() {
            if let value = try? element.attr(recipe.imageAttribute),
               !value.isEmpty {
                return resolveURL(value, base: baseURL)
            }
        }
        // Fall back to the first <img src> inside the item.
        if let img = try? item.select("img[src]").first(),
           let value = try? img.attr("src"), !value.isEmpty {
            return resolveURL(value, base: baseURL)
        }
        return nil
    }

    private static func extractDate(
        item: Element,
        recipe: PetalRecipe
    ) -> Date? {
        guard let selector = recipe.dateSelector, !selector.isEmpty,
              let element = try? item.select(selector).first() else {
            return nil
        }
        let raw: String
        if let attr = recipe.dateAttribute, !attr.isEmpty {
            raw = (try? element.attr(attr)) ?? ""
        } else {
            raw = (try? element.text()) ?? ""
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return parseFlexibleDate(trimmed)
    }

    // MARK: - Helpers

    /// Resolves a potentially relative URL against a base.  Mirrors
    /// the behavior of `ArticleExtractor.resolveURL` but kept local
    /// so the Petal engine has no cross-module dependency beyond
    /// Foundation + SwiftSoup.
    private static func resolveURL(_ href: String, base: URL?) -> String? {
        let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return trimmed
        }
        if trimmed.hasPrefix("//") {
            return "https:\(trimmed)"
        }
        guard let base else { return nil }
        return URL(string: trimmed, relativeTo: base)?.absoluteString
    }

    /// Parses timestamps using a handful of common formats.  Falls
    /// back to `ISO8601DateFormatter` and the system-locale date
    /// parsers so the builder doesn't need a date-format picker for
    /// the most common cases.
    private static func parseFlexibleDate(_ raw: String) -> Date? {
        if let iso = isoFormatter.date(from: raw) {
            return iso
        }
        if let isoFractional = isoFractionalFormatter.date(from: raw) {
            return isoFractional
        }
        for formatter in fallbackDateFormatters {
            if let date = formatter.date(from: raw) {
                return date
            }
        }
        return nil
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let isoFractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let fallbackDateFormatters: [DateFormatter] = {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
            "MMMM d, yyyy",
            "MMM d, yyyy",
            "d MMMM yyyy",
            "d MMM yyyy",
            "EEE, d MMM yyyy HH:mm:ss Z"
        ]
        return formats.map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            return formatter
        }
    }()
}
