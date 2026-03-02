import Foundation

nonisolated struct ParsedFeed: Sendable {
    var title: String
    var siteURL: String
    var description: String
    var articles: [ParsedArticle]
}

nonisolated struct ParsedArticle: Sendable {
    var title: String
    var url: String
    var author: String?
    var summary: String?
    var content: String?
    var imageURL: String?
    var publishedDate: Date?
}

nonisolated final class RSSParser: NSObject, XMLParserDelegate, @unchecked Sendable {

    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentDescription = ""
    private var currentAuthor = ""
    private var currentContent = ""
    private var currentPubDate = ""
    private var currentImageURL = ""

    private var feedTitle = ""
    private var feedLink = ""
    private var feedDescription = ""

    private var parsedArticles: [ParsedArticle] = []
    private var isInsideItem = false
    private var isInsideImage = false
    private var isAtom = false
    private var currentAttributes: [String: String] = [:]

    func parse(data: Data) -> ParsedFeed? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        resetState()
        guard parser.parse() else { return nil }
        return ParsedFeed(
            title: decodeHTMLEntities(feedTitle.trimmingCharacters(in: .whitespacesAndNewlines)),
            siteURL: feedLink.trimmingCharacters(in: .whitespacesAndNewlines),
            description: decodeHTMLEntities(feedDescription.trimmingCharacters(in: .whitespacesAndNewlines)),
            articles: parsedArticles
        )
    }

    private func resetState() {
        currentElement = ""
        currentTitle = ""
        currentLink = ""
        currentDescription = ""
        currentAuthor = ""
        currentContent = ""
        currentPubDate = ""
        currentImageURL = ""
        feedTitle = ""
        feedLink = ""
        feedDescription = ""
        parsedArticles = []
        isInsideItem = false
        isInsideImage = false
        isAtom = false
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        currentAttributes = attributeDict

        switch elementName {
        case "feed":
            isAtom = true
        case "image":
            if !isInsideItem { isInsideImage = true }
        case "item", "entry":
            isInsideItem = true
            resetItemState()
        case "link" where isAtom:
            handleAtomLink(attributeDict)
        case "enclosure", "media:content":
            handleMediaElement(elementName, attributes: attributeDict)
        case "media:thumbnail":
            if let url = attributeDict["url"] {
                currentImageURL = url
            }
        case "itunes:image" where isInsideItem:
            if let url = attributeDict["href"], currentImageURL.isEmpty {
                currentImageURL = url
            }
        default:
            break
        }
    }

    private func resetItemState() {
        currentTitle = ""
        currentLink = ""
        currentDescription = ""
        currentAuthor = ""
        currentContent = ""
        currentPubDate = ""
        currentImageURL = ""
    }

    private func handleAtomLink(_ attributes: [String: String]) {
        let rel = attributes["rel"] ?? "alternate"
        guard let href = attributes["href"], rel == "alternate" else { return }
        if isInsideItem {
            currentLink = href
        } else {
            feedLink = href
        }
    }

    private func handleMediaElement(_ elementName: String, attributes: [String: String]) {
        guard let url = attributes["url"], !url.isEmpty else { return }

        if let type = attributes["type"], type.hasPrefix("image/") {
            currentImageURL = url
        } else if attributes["medium"] == "image" {
            currentImageURL = url
        } else if elementName == "media:content", currentImageURL.isEmpty {
            currentImageURL = url
        } else if elementName == "enclosure",
                  let type = attributes["type"], type.hasPrefix("image/") {
            currentImageURL = url
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isInsideItem {
            appendItemCharacters(string)
        } else {
            appendFeedCharacters(string)
        }
    }

    private func appendItemCharacters(_ string: String) {
        switch currentElement {
        case "title": currentTitle += string
        case "link": if !isAtom { currentLink += string }
        case "description", "summary", "subtitle": currentDescription += string
        case "dc:creator", "author", "name": currentAuthor += string
        case "content:encoded", "content": currentContent += string
        case "pubDate", "published", "updated", "dc:date": currentPubDate += string
        default: break
        }
    }

    private func appendFeedCharacters(_ string: String) {
        guard !isInsideImage else { return }
        switch currentElement {
        case "title": feedTitle += string
        case "link": if !isAtom { feedLink += string }
        case "description", "subtitle": feedDescription += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "image" {
            isInsideImage = false
        } else if elementName == "item" || elementName == "entry" {
            let trimmedAuthor = currentAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedContent = currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
            let article = ParsedArticle(
                title: decodeHTMLEntities(currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)),
                url: currentLink.trimmingCharacters(in: .whitespacesAndNewlines),
                author: trimmedAuthor.isEmpty ? nil : decodeHTMLEntities(trimmedAuthor),
                summary: cleanHTML(currentDescription.trimmingCharacters(in: .whitespacesAndNewlines)),
                content: trimmedContent.isEmpty ? nil : trimmedContent,
                imageURL: resolveImageURL(),
                publishedDate: parseDate(currentPubDate.trimmingCharacters(in: .whitespacesAndNewlines))
            )
            if !article.title.isEmpty && !article.url.isEmpty {
                parsedArticles.append(article)
            }
            isInsideItem = false
        }
        currentElement = ""
    }

    // MARK: - Image Resolution

    private func resolveImageURL() -> String? {
        // Prefer explicitly tagged image from feed elements
        if !currentImageURL.isEmpty {
            return currentImageURL
        }
        // Try extracting from content:encoded (usually has full article HTML)
        if !currentContent.isEmpty, let url = extractImageFromHTML(currentContent) {
            return url
        }
        // Try extracting from description/summary
        if !currentDescription.isEmpty, let url = extractImageFromHTML(currentDescription) {
            return url
        }
        return nil
    }

    // MARK: - Date Parsing

    private static let dateFormatters: [DateFormatter] = {
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        ]
        return formats.map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            return formatter
        }
    }()

    nonisolated(unsafe) private static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    nonisolated(unsafe) private static let iso8601Standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private func parseDate(_ string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        for formatter in Self.dateFormatters {
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }

        return Self.iso8601WithFractional.date(from: trimmed)
            ?? Self.iso8601Standard.date(from: trimmed)
    }

}

// MARK: - HTML Entity Decoding

nonisolated private let htmlNamedEntities: [String: String] = [
    "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'",
    "nbsp": "\u{00A0}", "iexcl": "\u{00A1}", "cent": "\u{00A2}",
    "pound": "\u{00A3}", "curren": "\u{00A4}", "yen": "\u{00A5}",
    "brvbar": "\u{00A6}", "sect": "\u{00A7}", "uml": "\u{00A8}",
    "copy": "\u{00A9}", "ordf": "\u{00AA}", "laquo": "\u{00AB}",
    "not": "\u{00AC}", "shy": "\u{00AD}", "reg": "\u{00AE}",
    "macr": "\u{00AF}", "deg": "\u{00B0}", "plusmn": "\u{00B1}",
    "sup2": "\u{00B2}", "sup3": "\u{00B3}", "acute": "\u{00B4}",
    "micro": "\u{00B5}", "para": "\u{00B6}", "middot": "\u{00B7}",
    "cedil": "\u{00B8}", "sup1": "\u{00B9}", "ordm": "\u{00BA}",
    "raquo": "\u{00BB}", "frac14": "\u{00BC}", "frac12": "\u{00BD}",
    "frac34": "\u{00BE}", "iquest": "\u{00BF}",
    "times": "\u{00D7}", "divide": "\u{00F7}",
    "ndash": "\u{2013}", "mdash": "\u{2014}",
    "lsquo": "\u{2018}", "rsquo": "\u{2019}",
    "sbquo": "\u{201A}", "ldquo": "\u{201C}", "rdquo": "\u{201D}",
    "bdquo": "\u{201E}", "dagger": "\u{2020}", "Dagger": "\u{2021}",
    "bull": "\u{2022}", "hellip": "\u{2026}",
    "permil": "\u{2030}", "prime": "\u{2032}", "Prime": "\u{2033}",
    "lsaquo": "\u{2039}", "rsaquo": "\u{203A}",
    "oline": "\u{203E}", "frasl": "\u{2044}",
    "euro": "\u{20AC}", "trade": "\u{2122}",
    "larr": "\u{2190}", "uarr": "\u{2191}", "rarr": "\u{2192}", "darr": "\u{2193}",
    "harr": "\u{2194}", "lArr": "\u{21D0}", "uArr": "\u{21D1}",
    "rArr": "\u{21D2}", "dArr": "\u{21D3}", "hArr": "\u{21D4}",
    "minus": "\u{2212}", "lowast": "\u{2217}",
    "le": "\u{2264}", "ge": "\u{2265}", "ne": "\u{2260}",
    "equiv": "\u{2261}", "sum": "\u{2211}", "prod": "\u{220F}",
    "infin": "\u{221E}", "radic": "\u{221A}",
    "spades": "\u{2660}", "clubs": "\u{2663}",
    "hearts": "\u{2665}", "diams": "\u{2666}"
]

nonisolated extension RSSParser {

    func decodeHTMLEntities(_ string: String) -> String {
        guard string.contains("&") else { return string }

        var result = ""
        var index = string.startIndex

        while index < string.endIndex {
            if string[index] == "&" {
                if let semiIndex = string[index...].firstIndex(of: ";"),
                   semiIndex > string.index(after: index) {
                    let entity = String(string[string.index(after: index)..<semiIndex])

                    if let decoded = decodeEntity(entity) {
                        result.append(decoded)
                        index = string.index(after: semiIndex)
                        continue
                    }
                }
            }

            result.append(string[index])
            index = string.index(after: index)
        }

        return result
    }

    func decodeEntity(_ entity: String) -> String? {
        if entity.hasPrefix("#x") || entity.hasPrefix("#X") {
            let hex = String(entity.dropFirst(2))
            if let code = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(code) {
                return String(Character(scalar))
            }
        } else if entity.hasPrefix("#") {
            let decimal = String(entity.dropFirst())
            if let code = UInt32(decimal), let scalar = Unicode.Scalar(code) {
                return String(Character(scalar))
            }
        } else if let replacement = htmlNamedEntities[entity] {
            return replacement
        }
        return nil
    }

    func cleanHTML(_ html: String) -> String? {
        let stripped = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let decoded = decodeHTMLEntities(stripped)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return decoded.isEmpty ? nil : decoded
    }

    func extractImageFromHTML(_ html: String) -> String? {
        // Try double-quoted src first, then single-quoted
        let patterns = [
            #"<img[^>]+src="([^"]+)""#,
            #"<img[^>]+src='([^']+)'"#
        ]
        for pattern in patterns {
            if let range = html.range(of: pattern, options: .regularExpression) {
                let match = html[range]
                if let srcRange = match.range(of: #"src=["']([^"']+)["']"#, options: .regularExpression) {
                    let src = match[srcRange]
                    let url = src.dropFirst(5).dropLast(1)
                    let urlString = String(url)
                    if isLikelyHeroImage(urlString) {
                        return urlString
                    }
                }
            }
        }
        // No hero-quality image found, return first image as fallback
        for pattern in patterns {
            if let range = html.range(of: pattern, options: .regularExpression) {
                let match = html[range]
                if let srcRange = match.range(of: #"src=["']([^"']+)["']"#, options: .regularExpression) {
                    let src = match[srcRange]
                    let url = src.dropFirst(5).dropLast(1)
                    return String(url)
                }
            }
        }
        return nil
    }

    private func isLikelyHeroImage(_ url: String) -> Bool {
        let lowered = url.lowercased()
        // Skip tracking pixels, icons, and spacers
        let skipPatterns = [
            "gravatar.com", "pixel", "spacer", "blank",
            "1x1", "transparent", "tracking", "beacon",
            ".gif", "feeds.feedburner.com", "badge",
            "icon", "emoji", "smiley", "avatar",
            "ad.", "ads.", "doubleclick", "googlesyndication"
        ]
        for pattern in skipPatterns {
            if lowered.contains(pattern) { return false }
        }
        return true
    }
}
