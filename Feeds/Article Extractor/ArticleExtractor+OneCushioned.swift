import Foundation
import SwiftSoup

extension ArticleExtractor {

    static func oneCushionedArticleURL(
        fromHTML html: String,
        baseURL: URL
    ) -> URL? {
        guard let selector = OneCushionedDomains.selector(for: baseURL) else {
            return nil
        }
        return oneCushionedArticleURL(
            fromHTML: html, baseURL: baseURL, selector: selector
        )
    }

    static func oneCushionedArticleURL(
        fromHTML html: String,
        baseURL: URL,
        selector: String
    ) -> URL? {
        guard !html.isEmpty else { return nil }
        guard let doc = try? SwiftSoup.parse(html) else { return nil }
        guard let anchor = try? doc.select(selector).first() else { return nil }
        guard let href = try? anchor.attr("href"),
              !href.isEmpty else { return nil }
        return URL(string: href, relativeTo: baseURL)?.absoluteURL
    }

    static func resolveOneCushionedURL(_ url: URL) async -> URL {
        guard OneCushionedDomains.isOneCushioned(url: url) else { return url }
        do {
            let request = URLRequest.sakura(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let html = HTMLDataDecoder.decode(data, response: response) else {
                return url
            }
            return oneCushionedArticleURL(fromHTML: html, baseURL: url) ?? url
        } catch {
            return url
        }
    }
}
