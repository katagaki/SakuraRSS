import Foundation
import SwiftSoup

extension ArticleExtractor {

    private static let maxAdditionalPages = 4

    /// Finds "next page" links on a document and fetches up to
    /// `maxAdditionalPages` additional pages, returning their extracted
    /// text concatenated with `\n\n` separators.  Respects the feature
    /// flag at `UserDefaults.standard.bool(forKey: "ArticleParser.followPagination")`
    /// (defaults to enabled — returns `false` only when explicitly disabled).
    static func fetchPaginatedExtras(
        from html: String,
        baseURL: URL,
        excludeTitle: String? = nil
    ) async -> String? {
        let defaults = UserDefaults.standard
        let key = "ArticleParser.followPagination"
        if defaults.object(forKey: key) != nil, !defaults.bool(forKey: key) {
            return nil
        }

        let urls = nextPageURLs(from: html, baseURL: baseURL)
        guard !urls.isEmpty else { return nil }

        var combined: [String] = []
        var visited: Set<String> = [baseURL.absoluteString]
        for nextURL in urls.prefix(maxAdditionalPages) {
            if visited.contains(nextURL.absoluteString) { continue }
            visited.insert(nextURL.absoluteString)

            do {
                let (data, response) = try await URLSession.shared.data(
                    for: URLRequest.sakura(url: nextURL)
                )
                guard let pageHTML = HTMLDataDecoder.decode(data, response: response) else {
                    continue
                }
                if let text = extractText(
                    fromHTML: pageHTML,
                    baseURL: nextURL,
                    excludeTitle: excludeTitle
                ), !text.isEmpty {
                    combined.append(text)
                }
            } catch {
                continue
            }
        }
        return combined.isEmpty ? nil : combined.joined(separator: "\n\n")
    }

    /// Locates candidate next-page URLs from rel=next links and common
    /// "Next" anchors.  Returns unique URLs in DOM order.
    static func nextPageURLs(from html: String, baseURL: URL) -> [URL] {
        guard let doc = try? SwiftSoup.parse(html, baseURL.absoluteString) else {
            return []
        }
        var urls: [URL] = []
        var seen: Set<String> = []

        let addIfNew: (String) -> Void = { href in
            guard let resolved = URL(string: href, relativeTo: baseURL)?.absoluteURL
            else { return }
            let absolute = resolved.absoluteString
            if seen.contains(absolute) { return }
            seen.insert(absolute)
            urls.append(resolved)
        }

        if let relNext = try? doc.select("link[rel=next], a[rel=next]") {
            for element in relNext {
                if let href = try? element.attr("href"), !href.isEmpty {
                    addIfNew(href)
                }
            }
        }

        let selectors = [
            "a.next", "a.next-page", "a.pagination-next",
            "a[aria-label=Next]", "a[aria-label=\"Next page\"]",
            "a.pagenextload"
        ]
        for selector in selectors {
            if let elements = try? doc.select(selector) {
                for element in elements {
                    if let href = try? element.attr("href"), !href.isEmpty {
                        addIfNew(href)
                    }
                }
            }
        }

        if let anchors = try? doc.select("a[href]") {
            for anchor in anchors.prefix(300) {
                let text = ((try? anchor.text()) ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                if text == "next" || text == "next >" || text == "next ›"
                    || text == "next page" || text == "›" {
                    if let href = try? anchor.attr("href"), !href.isEmpty {
                        addIfNew(href)
                    }
                }
            }
        }

        return urls
    }
}
