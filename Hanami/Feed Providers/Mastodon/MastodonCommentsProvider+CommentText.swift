import Foundation

public nonisolated extension MastodonCommentsProvider {

    /// Strips a Mastodon status `content` HTML fragment down to plain text,
    /// preserving paragraph breaks. Mastodon emits `<p>`, `<br>`, `<a>`, and
    /// `<span>`, so the same lightweight approach the other comment providers
    /// use is sufficient (and avoids linking SwiftSoup into this path).
    static func cleanCommentText(_ html: String) -> String {
        var text = html
        text = text.replacingOccurrences(
            of: #"<p\s*/?>"#, with: "\n\n",
            options: [.regularExpression, .caseInsensitive]
        )
        text = text.replacingOccurrences(
            of: "</p>", with: "", options: .caseInsensitive
        )
        text = text.replacingOccurrences(
            of: #"<br\s*/?>"#, with: "\n",
            options: [.regularExpression, .caseInsensitive]
        )
        text = text.replacingOccurrences(
            of: #"<[^>]+>"#, with: "", options: .regularExpression
        )
        text = decodeBasicEntities(text)
        text = text.replacingOccurrences(
            of: #"\n{3,}"#, with: "\n\n", options: .regularExpression
        )
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeBasicEntities(_ text: String) -> String {
        let entityMap: [(String, String)] = [
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&apos;", "'"),
            ("&#x27;", "'"),
            ("&#39;", "'"),
            ("&#x2F;", "/"),
            ("&#47;", "/"),
            ("&nbsp;", " ")
        ]
        var result = text
        for (entity, replacement) in entityMap {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        return result
    }
}
