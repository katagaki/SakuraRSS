import Foundation

nonisolated struct RSSParserCaptureFrame {
    let elementName: String
    let depth: Int
    let isXHTML: Bool
}

nonisolated extension RSSParser {

    static let capturedTextElements: Set<String> = [
        "title", "link", "description", "summary", "subtitle", "media:description",
        "dc:creator", "author", "name", "content:encoded", "content",
        "pubDate", "published", "dc:date", "updated", "itunes:duration", "generator"
    ]

    static let ignoredNestedElements: Set<String> = [
        "email", "uri", "id", "guid", "category", "comments", "source"
    ]

    static func isCaptureBoundary(_ elementName: String) -> Bool {
        capturedTextElements.contains(elementName) || ignoredNestedElements.contains(elementName)
    }

    static func isXHTMLContainer(_ elementName: String, attributes: [String: String]) -> Bool {
        guard attributes["type"] == "xhtml" else { return false }
        return elementName == "content" || elementName == "summary" || elementName == "title"
    }

    static func openingTagMarkup(_ elementName: String, attributes: [String: String]) -> String {
        let attributeMarkup = attributes
            .sorted { $0.key < $1.key }
            .map { " \($0.key)=\"\(escapeXMLAttribute($0.value))\"" }
            .joined()
        return "<\(elementName)\(attributeMarkup)>"
    }

    static func escapeXMLText(_ text: String) -> String {
        guard text.contains("&") || text.contains("<") || text.contains(">") else { return text }
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    static func escapeXMLAttribute(_ text: String) -> String {
        escapeXMLText(text).replacingOccurrences(of: "\"", with: "&quot;")
    }
}
