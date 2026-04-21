import Foundation

/// Domains whose feeds carry the meaningful article text in the
/// body/summary while the `<title>` element holds a generic category
/// label (e.g. the JMA extra feed at
/// https://www.data.jma.go.jp/developer/xml/feed/extra.xml). For these
/// feeds, the title and body are swapped so lists surface the useful
/// information first.
nonisolated enum BodyPriorityDomains {

    static let allowlistedDomains: Set<String> = [
        "data.jma.go.jp"
    ]

    static func shouldSwapTitleAndBody(feedDomain: String) -> Bool {
        let host = feedDomain.lowercased()
        return allowlistedDomains.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
    }

    /// Returns a copy of `article` with title and body swapped when the
    /// feed's domain is in the allowlist. The body is sourced from
    /// `summary` when present, otherwise from `content`.
    static func applying(to article: ParsedArticle, feedDomain: String) -> ParsedArticle {
        guard shouldSwapTitleAndBody(feedDomain: feedDomain) else { return article }

        let bodySource = article.summary?.trimmingCharacters(in: .whitespacesAndNewlines)
        let contentSource = article.content?.trimmingCharacters(in: .whitespacesAndNewlines)
        let newTitle: String
        let newSummary: String?
        if let bodySource, !bodySource.isEmpty {
            newTitle = bodySource
            newSummary = article.title
        } else if let contentSource, !contentSource.isEmpty {
            newTitle = contentSource
            newSummary = article.title
        } else {
            return article
        }

        var swapped = article
        swapped.title = collapseWhitespace(newTitle)
        swapped.summary = newSummary
        return swapped
    }

    private static func collapseWhitespace(_ text: String) -> String {
        let collapsed = text.replacingOccurrences(
            of: #"\s+"#, with: " ", options: .regularExpression
        )
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
