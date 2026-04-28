import Foundation
import SwiftSoup

extension ArticleExtractor {

    /// Extracts author, publish date, and lead image. Call before `removeNoise`.
    static func extractMetadata(from doc: Document) -> ArticleMetadata {
        var metadata = ArticleMetadata()

        if let jsonLD = metadataFromJSONLD(in: doc) {
            metadata.author = metadata.author ?? jsonLD.author
            metadata.publishedDate = metadata.publishedDate ?? jsonLD.publishedDate
            metadata.leadImageURL = metadata.leadImageURL ?? jsonLD.leadImageURL
        }

        // swiftlint:disable:next identifier_name
        if let og = metadataFromMetaTags(in: doc) {
            metadata.author = metadata.author ?? og.author
            metadata.publishedDate = metadata.publishedDate ?? og.publishedDate
            metadata.leadImageURL = metadata.leadImageURL ?? og.leadImageURL
        }

        if metadata.author == nil, let author = authorFromSemanticTags(in: doc) {
            metadata.author = author
        }
        if metadata.publishedDate == nil, let date = dateFromTimeTags(in: doc) {
            metadata.publishedDate = date
        }

        metadata.pageTitle = pageTitleFromDocument(doc)

        return metadata
    }

    /// Pulls a human-readable page title, preferring `og:title` over the raw
    /// `<title>` element so we sidestep "Site Name | Article Title" cruft.
    static func pageTitleFromDocument(_ doc: Document) -> String? {
        let metaSelectors = [
            "meta[property=og:title]",
            "meta[name=twitter:title]",
            "meta[name=title]"
        ]
        for selector in metaSelectors {
            if let element = try? doc.select(selector).first(),
               let value = try? element.attr("content") {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        if let title = try? doc.title() {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }

    // MARK: - JSON-LD

    private static let jsonLDTypes: Set<String> = [
        "newsarticle", "article", "blogposting", "report",
        "analysisnewsarticle", "reviewnewsarticle", "opinionnewsarticle"
    ]

    private static func metadataFromJSONLD(in doc: Document) -> ArticleMetadata? {
        guard let scripts = try? doc.select(
            "script[type=application/ld+json]"
        ) else { return nil }
        var result = ArticleMetadata()
        for script in scripts {
            let raw = script.data()
            guard !raw.isEmpty, let data = raw.data(using: .utf8) else { continue }
            let jsonObjects = decodeJSONLDObjects(from: data)
            for object in jsonObjects {
                guard isArticleType(object["@type"]) else { continue }
                if result.author == nil,
                   let author = authorValue(from: object["author"]) {
                    result.author = author
                }
                if result.publishedDate == nil,
                   let raw = object["datePublished"] as? String,
                   let date = parseISODate(raw) {
                    result.publishedDate = date
                }
                if result.leadImageURL == nil,
                   let image = imageValue(from: object["image"]) {
                    result.leadImageURL = image
                }
            }
        }
        return result
    }

    private static func decodeJSONLDObjects(from data: Data) -> [[String: Any]] {
        guard let parsed = try? JSONSerialization.jsonObject(
            with: data, options: [.fragmentsAllowed]
        ) else { return [] }
        if let dict = parsed as? [String: Any] {
            if let graph = dict["@graph"] as? [[String: Any]] {
                return graph
            }
            return [dict]
        }
        if let array = parsed as? [[String: Any]] {
            return array
        }
        return []
    }

    private static func isArticleType(_ value: Any?) -> Bool {
        if let single = value as? String {
            return jsonLDTypes.contains(single.lowercased())
        }
        if let multiple = value as? [String] {
            return multiple.contains { jsonLDTypes.contains($0.lowercased()) }
        }
        return false
    }

    private static func authorValue(from value: Any?) -> String? {
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let dict = value as? [String: Any],
           let name = dict["name"] as? String {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        if let array = value as? [Any] {
            let names = array.compactMap { authorValue(from: $0) }
            if !names.isEmpty {
                return names.joined(separator: ", ")
            }
        }
        return nil
    }

    private static func imageValue(from value: Any?) -> String? {
        if let string = value as? String {
            return string.isEmpty ? nil : string
        }
        if let dict = value as? [String: Any] {
            if let url = dict["url"] as? String, !url.isEmpty { return url }
            if let contentURL = dict["contentUrl"] as? String, !contentURL.isEmpty {
                return contentURL
            }
        }
        if let array = value as? [Any] {
            for item in array {
                if let url = imageValue(from: item) { return url }
            }
        }
        return nil
    }

    // MARK: - Meta tags (OpenGraph / Twitter)

    private static func metadataFromMetaTags(in doc: Document) -> ArticleMetadata? {
        var result = ArticleMetadata()

        if let author = metaContent(in: doc, property: "article:author")
            ?? metaContent(in: doc, name: "author") {
            result.author = author
        }

        if let raw = metaContent(in: doc, property: "article:published_time")
            ?? metaContent(in: doc, property: "og:article:published_time")
            ?? metaContent(in: doc, name: "pubdate")
            ?? metaContent(in: doc, name: "publish_date")
            ?? metaContent(in: doc, name: "date"),
           let date = parseISODate(raw) {
            result.publishedDate = date
        }

        if let image = metaContent(in: doc, property: "og:image")
            ?? metaContent(in: doc, name: "twitter:image")
            ?? metaContent(in: doc, property: "twitter:image") {
            result.leadImageURL = image
        }

        return result
    }

    private static func metaContent(
        in doc: Document, property: String
    ) -> String? {
        guard let elements = try? doc.select("meta[property=\(property)]") else {
            return nil
        }
        for element in elements {
            if let content = try? element.attr("content"),
               !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return content.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private static func metaContent(
        in doc: Document, name: String
    ) -> String? {
        guard let elements = try? doc.select("meta[name=\(name)]") else {
            return nil
        }
        for element in elements {
            if let content = try? element.attr("content"),
               !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return content.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    // MARK: - Semantic fallbacks

    private static func authorFromSemanticTags(in doc: Document) -> String? {
        let selectors = [
            "[itemprop=author] [itemprop=name]",
            "[itemprop=author]",
            "[rel=author]",
            "a[rel=author]",
            ".author-name",
            ".byline-author",
            ".byline .author"
        ]
        for selector in selectors {
            if let element = try? doc.select(selector).first() {
                let text = (try? element.text()) ?? ""
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    private static func dateFromTimeTags(in doc: Document) -> Date? {
        let candidates = [
            "time[datetime]",
            "[itemprop=datePublished]",
            "[property=article:published_time]"
        ]
        for selector in candidates {
            guard let elements = try? doc.select(selector) else { continue }
            for element in elements {
                let datetime = (try? element.attr("datetime")) ?? ""
                let content = (try? element.attr("content")) ?? ""
                if let date = parseISODate(datetime.isEmpty ? content : datetime) {
                    return date
                }
                let text = (try? element.text()) ?? ""
                if let date = parseISODate(text) { return date }
            }
        }
        return nil
    }

    // MARK: - Date parsing

    private static let isoFormatters: [ISO8601DateFormatter] = {
        let withFractions = ISO8601DateFormatter()
        withFractions.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return [withFractions, plain]
    }()

    private static let fallbackFormatters: [DateFormatter] = {
        let locale = Locale(identifier: "en_US_POSIX")
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "MMM d, yyyy"
        ]
        return formats.map {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.dateFormat = $0
            return formatter
        }
    }()

    private static func parseISODate(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        for formatter in isoFormatters {
            if let date = formatter.date(from: trimmed) { return date }
        }
        for formatter in fallbackFormatters {
            if let date = formatter.date(from: trimmed) { return date }
        }
        return nil
    }
}
