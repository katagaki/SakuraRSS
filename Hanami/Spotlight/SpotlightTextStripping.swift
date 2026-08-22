import Foundation

extension SpotlightIndexer {

    /// `NSRegularExpression` is documented as thread-safe once compiled, so these
    /// shared instances replace per-call pattern compilation on the indexing path.
    nonisolated(unsafe) static let imageMarkerExpression = SpotlightTextStripping.compile(
        "\\{\\{IMG\\}\\}.*?\\{\\{/IMG\\}\\}"
    )
    nonisolated(unsafe) static let markdownImageExpression = SpotlightTextStripping.compile("!\\[[^\\]]*\\]\\([^)]*\\)")
    nonisolated(unsafe) static let markdownLinkExpression = SpotlightTextStripping.compile("\\[([^\\]]+)\\]\\([^)]*\\)")
    nonisolated(unsafe) static let bareURLExpression = SpotlightTextStripping.compile("https?://\\S+")
    nonisolated(unsafe) static let htmlTagExpression = SpotlightTextStripping.compile("<[^>]+>")
    nonisolated(unsafe) static let whitespaceRunExpression = SpotlightTextStripping.compile("\\s+")

    nonisolated static func replacingMatches(
        _ text: String,
        _ expression: NSRegularExpression?,
        with template: String
    ) -> String {
        guard let expression else { return text }
        return expression.stringByReplacingMatches(
            in: text,
            options: [],
            range: NSRange(text.startIndex..., in: text),
            withTemplate: template
        )
    }

    nonisolated static func decodingEntities(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        return result
    }
}

enum SpotlightTextStripping {

    nonisolated static func compile(_ pattern: String) -> NSRegularExpression? {
        try? NSRegularExpression(pattern: pattern)
    }
}
