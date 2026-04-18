import Foundation
import SwiftSoup

extension ArticleExtractor {

    private static let googleAMPHosts: Set<String> = ["google.com", "www.google.com"]
    private static let googleAMPPathPrefix = "/amp/s/"

    /// Unwraps Google AMP viewer URLs (`https://www.google.com/amp/s/<host>/<path>`)
    /// to the canonical URL they wrap.  Returns the input unchanged for
    /// non-AMP URLs.
    static func unwrapGoogleAMPURL(_ url: URL) -> URL {
        guard let host = url.host?.lowercased(),
              googleAMPHosts.contains(host) else {
            return url
        }
        let path = url.path
        guard path.hasPrefix(googleAMPPathPrefix) else { return url }
        let trimmed = String(path.dropFirst(googleAMPPathPrefix.count))
        // trimmed is "<host>/<path>" — prepend scheme.
        let candidate = "https://\(trimmed)"
        return URL(string: candidate) ?? url
    }

    /// Scans the document for `<link rel="amphtml" href="…">` and returns
    /// the first such URL resolved against the base URL.  AMP pages have
    /// mechanically cleaner markup that extracts better when the canonical
    /// page is JS-heavy.
    static func amphtmlURL(from html: String, baseURL: URL) -> URL? {
        guard let doc = try? SwiftSoup.parse(html, baseURL.absoluteString),
              let link = try? doc.select("link[rel=amphtml]").first(),
              let href = try? link.attr("href"), !href.isEmpty else {
            return nil
        }
        return URL(string: href, relativeTo: baseURL)?.absoluteURL
    }

    /// Treats `<amp-video>` and `<amp-youtube>` elements as regular `<video>`
    /// and YouTube embeds by rewriting them in-place.  Call before
    /// `promoteInlineEmbeds`.
    static func normalizeAMPElements(in doc: Document) {
        if let ampYouTubes = try? doc.select("amp-youtube") {
            for element in ampYouTubes {
                let videoID = (try? element.attr("data-videoid")) ?? ""
                guard !videoID.isEmpty else { continue }
                let src = "https://www.youtube.com/embed/\(videoID)"
                _ = try? element.tagName("iframe")
                _ = try? element.attr("src", src)
            }
        }
        if let ampVideos = try? doc.select("amp-video") {
            for element in ampVideos {
                _ = try? element.tagName("video")
            }
        }
        if let ampImages = try? doc.select("amp-img") {
            for element in ampImages {
                _ = try? element.tagName("img")
            }
        }
    }
}
