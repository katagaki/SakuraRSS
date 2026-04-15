import Foundation
import SwiftSoup

nonisolated extension PetalEngine {

    // MARK: - Parsing

    /// Runs the recipe's selectors against the given HTML.
    /// Public so the builder can feed pre-fetched HTML in
    /// without re-fetching on every keystroke.
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
        // Link — required.  Without a URL there's nothing to show.
        guard let linkString = extractLink(item: item, recipe: recipe),
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

    // MARK: - Field extractors

    private static func extractLink(
        item: Element,
        recipe: PetalRecipe
    ) -> String? {
        if let selector = recipe.linkSelector,
           let element = try? item.select(selector).first(),
           let value = try? element.attr(recipe.linkAttribute),
           !value.isEmpty {
            return value
        }
        // Fall back to the first <a href> inside the item.
        if let anchor = try? item.select("a[href]").first(),
           let href = try? anchor.attr("href"), !href.isEmpty {
            return href
        }
        return nil
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

    // MARK: - URL resolution

    /// Resolves a potentially relative URL against a base.
    /// Mirrors `ArticleExtractor.resolveURL` but kept local so
    /// the engine has no cross-module dependency beyond
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
}
