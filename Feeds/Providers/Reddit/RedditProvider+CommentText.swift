import Foundation

nonisolated extension RedditProvider {

    /// Strips the small HTML fragment that the Reddit shreddit svc returns inside
    /// a comment's body div down to plain text, preserving paragraph breaks.
    /// Reddit comment bodies use `<p>`, `<br>`, `<a>`, `<strong>`, `<em>`, `<s>`,
    /// `<code>`, `<pre>`, and list tags; SwiftSoup is not linked to every target
    /// that ships this provider, so a regex pass is sufficient here.
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
            of: #"<li\s*/?>"#, with: "\n• ",
            options: [.regularExpression, .caseInsensitive]
        )
        text = text.replacingOccurrences(
            of: #"<pre\s*/?>"#, with: "\n",
            options: [.regularExpression, .caseInsensitive]
        )
        text = text.replacingOccurrences(
            of: #"<[^>]+>"#, with: "", options: .regularExpression
        )
        text = decodeBasicEntities(text)
        text = text.replacingOccurrences(
            of: #"[ \t]+"#, with: " ", options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"\n[ \t]+"#, with: "\n", options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"\n{3,}"#, with: "\n\n", options: .regularExpression
        )
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let entityMap: [(String, String)] = [
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

    private static func decodeBasicEntities(_ text: String) -> String {
        var result = text
        for (entity, replacement) in entityMap {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        return result
    }
}
