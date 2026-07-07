import Foundation

/// Reddit serves `/comments/<id>.json` behind bot verification on some
/// networks, but the Atom entry HTML stored on the article still describes
/// the post: self posts carry their body between `SC_OFF`/`SC_ON` comment
/// markers, and other posts carry a `[link]` anchor to the target.
public extension RedditProvider {

    nonisolated static func extractPostResult(fromEntryOf article: Article) async -> RedditPostFetchResult? {
        guard let entryHTML = article.content, !entryHTML.isEmpty else { return nil }

        let selftext = await extractEntrySelftext(fromEntryHTML: entryHTML, articleURL: article.url)
        guard let linkTarget = extractEntryLinkTarget(fromEntryHTML: entryHTML),
              let host = linkTarget.host?.lowercased() else {
            guard let selftext else { return nil }
            return .markerString(selftext)
        }

        if host == "i.redd.it" || host == "preview.redd.it" {
            var markerLines: [String] = []
            if let selftext {
                markerLines.append(selftext)
            }
            markerLines.append("{{IMG}}\(linkTarget.absoluteString){{/IMG}}")
            return .markerString(markerLines.joined(separator: "\n\n"))
        }

        let isRedditFamilyHost = host == "reddit.com" || host.hasSuffix(".reddit.com")
            || host == "redd.it" || host.hasSuffix(".redd.it")
        if isRedditFamilyHost {
            if let selftext {
                return .markerString(selftext)
            }
            if let imageURL = article.imageURL, !imageURL.isEmpty {
                return .markerString("{{IMG}}\(imageURL){{/IMG}}")
            }
            return nil
        }

        return .linkedArticle(linkTarget)
    }

    private nonisolated static func extractEntrySelftext(
        fromEntryHTML entryHTML: String, articleURL: String
    ) async -> String? {
        guard let openRange = entryHTML.range(of: "<!-- SC_OFF -->"),
              let closeRange = entryHTML.range(
                of: "<!-- SC_ON -->",
                range: openRange.upperBound..<entryHTML.endIndex
              ) else { return nil }
        let bodyHTML = String(entryHTML[openRange.upperBound..<closeRange.lowerBound])
        guard let text = await HTMLContentExtractor.extractText(
            fromHTML: bodyHTML, baseURL: URL(string: articleURL)
        ), !text.isEmpty else { return nil }
        return text
    }

    private nonisolated static func extractEntryLinkTarget(fromEntryHTML entryHTML: String) -> URL? {
        let pattern = #"<a href="([^"]+)">\s*\[link\]\s*</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: entryHTML,
                range: NSRange(entryHTML.startIndex..., in: entryHTML)
              ),
              let hrefRange = Range(match.range(at: 1), in: entryHTML) else {
            return nil
        }
        return URL(string: unescapeAmpersand(String(entryHTML[hrefRange])))
    }
}
