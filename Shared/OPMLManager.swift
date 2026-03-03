import Foundation

nonisolated final class OPMLManager: @unchecked Sendable {

    static let shared = OPMLManager()

    private init() {}

    // MARK: - Export

    func generateOPML(from feeds: [Feed]) -> String {
        var lines: [String] = []
        lines.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
        lines.append("<opml version=\"2.0\">")
        lines.append("  <head>")
        lines.append("    <title>SakuraRSS Subscriptions</title>")
        lines.append("    <dateCreated>\(rfc822Date(Date()))</dateCreated>")
        lines.append("  </head>")
        lines.append("  <body>")

        let categorized = Dictionary(grouping: feeds) { $0.category ?? "" }
        let sortedKeys = categorized.keys.sorted()

        for key in sortedKeys {
            guard let group = categorized[key] else { continue }
            if key.isEmpty {
                for feed in group.sorted(by: { $0.title < $1.title }) {
                    lines.append("    \(outlineElement(for: feed))")
                }
            } else {
                lines.append("    <outline text=\"\(escapeXML(key))\" title=\"\(escapeXML(key))\">")
                for feed in group.sorted(by: { $0.title < $1.title }) {
                    lines.append("      \(outlineElement(for: feed))")
                }
                lines.append("    </outline>")
            }
        }

        lines.append("  </body>")
        lines.append("</opml>")
        return lines.joined(separator: "\n")
    }

    private func outlineElement(for feed: Feed) -> String {
        var attrs = "type=\"rss\""
        attrs += " text=\"\(escapeXML(feed.title))\""
        attrs += " title=\"\(escapeXML(feed.title))\""
        attrs += " xmlUrl=\"\(escapeXML(feed.url))\""
        if !feed.siteURL.isEmpty {
            attrs += " htmlUrl=\"\(escapeXML(feed.siteURL))\""
        }
        if !feed.feedDescription.isEmpty {
            attrs += " description=\"\(escapeXML(feed.feedDescription))\""
        }
        return "<outline \(attrs)/>"
    }

    // MARK: - Import

    func parseOPML(data: Data) -> [OPMLFeed] {
        let parser = OPMLXMLParser(data: data)
        return parser.parse()
    }

    // MARK: - Helpers

    private func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private func rfc822Date(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter.string(from: date)
    }
}

// MARK: - OPML Feed Model

nonisolated struct OPMLFeed: Sendable {
    let title: String
    let xmlURL: String
    let htmlURL: String
    let description: String
    let category: String?
}

// MARK: - OPML XML Parser

private nonisolated final class OPMLXMLParser: NSObject, XMLParserDelegate, @unchecked Sendable {

    private let data: Data
    private var feeds: [OPMLFeed] = []
    private var categoryStack: [String] = []
    private var isFeedOutline = false

    init(data: Data) {
        self.data = data
    }

    func parse() -> [OPMLFeed] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return feeds
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        guard elementName == "outline" else { return }

        if let xmlURL = attributes["xmlUrl"], !xmlURL.isEmpty {
            let title = attributes["title"] ?? attributes["text"] ?? xmlURL
            let htmlURL = attributes["htmlUrl"] ?? ""
            let description = attributes["description"] ?? ""
            let category = categoryStack.last

            feeds.append(OPMLFeed(
                title: title,
                xmlURL: xmlURL,
                htmlURL: htmlURL,
                description: description,
                category: category
            ))
            isFeedOutline = true
        } else {
            let folderName = attributes["title"] ?? attributes["text"] ?? ""
            categoryStack.append(folderName)
            isFeedOutline = false
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        guard elementName == "outline" else { return }
        if isFeedOutline {
            isFeedOutline = false
        } else if !categoryStack.isEmpty {
            categoryStack.removeLast()
        }
    }
}
