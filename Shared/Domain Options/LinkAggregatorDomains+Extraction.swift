import Foundation

extension LinkAggregatorDomains {

    /// Returns the first URL in a parsed summary that does not belong to any
    /// known link-aggregator host — typically the external "Article URL" on
    /// HN/hnrss-style entries.
    nonisolated static func linkedArticleURL(fromSummary summary: String) -> URL? {
        guard !summary.isEmpty,
              let regex = try? NSRegularExpression(pattern: #"\[[^\]]*\]\(([^)\s]+)\)"#) else {
            return nil
        }
        let ns = summary as NSString
        let regexMatches = regex.matches(in: summary, range: NSRange(location: 0, length: ns.length))
        for match in regexMatches where match.numberOfRanges >= 2 {
            let raw = ns.substring(with: match.range(at: 1))
            guard let url = URL(string: raw),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https",
                  let host = url.host?.lowercased(),
                  !matches(feedDomain: host) else { continue }
            return url
        }
        return nil
    }
}
