import Foundation
import SwiftSoup

extension ArticleExtractor {

    /// Extracts raw text from a code block element, preserving whitespace and newlines.
    static func codeContent(of element: Element) throws -> String {
        let source: Element
        if let codeChild = try? element.select("code").first() {
            source = codeChild
        } else if let preChild = try? element.select("pre").first() {
            source = preChild
        } else {
            source = element
        }

        // Code Hike-style blocks use one <div> per line inside <code>,
        // so extract line-by-line when children are line divs.
        let directDivs = source.children().filter {
            $0.tagName().lowercased() == "div"
        }
        if directDivs.count > 1 {
            let lines = try directDivs.map { try $0.text() }
            let text = lines.joined(separator: "\n")
            let decoded = decodeCodeEntities(text)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\n"))
            return ArticleMarker.escape(decoded)
        }

        var html = try source.html()
        html = html.replacingOccurrences(
            of: #"<br\s*/?>"#, with: "\n", options: .regularExpression
        )
        html = html.replacingOccurrences(
            of: "<[^>]+>", with: "", options: .regularExpression
        )
        let decoded = decodeCodeEntities(html)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\n"))
        return ArticleMarker.escape(decoded)
    }

    static func decodeCodeEntities(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&apos;", with: "'")
        result = result.replacingOccurrences(of: "&#x27;", with: "'")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        return result
    }
}
