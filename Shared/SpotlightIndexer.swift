import CoreSpotlight
import Foundation

nonisolated enum SpotlightIndexer {

    static let domainIdentifier = "com.tsubuzaki.SakuraRSS.article"

    // MARK: - Indexing

    static func indexArticles(_ articles: [Article], feedTitle: String?) {
        guard !articles.isEmpty else { return }

        let entries = articles.map { article in
            IndexEntry(
                identifier: uniqueIdentifier(for: article.id),
                title: article.title,
                contentDescription: article.summary.flatMap { stripMarkup($0) }
                    ?? article.content.flatMap { stripHTML($0) },
                author: article.author,
                publishedDate: article.publishedDate,
                url: URL(string: article.url),
                thumbnailURL: article.imageURL.flatMap { URL(string: $0) },
                feedTitle: feedTitle
            )
        }

        Task { @MainActor in
            let items = entries.map { entry -> CSSearchableItem in
                let attributes = CSSearchableItemAttributeSet(contentType: .text)
                attributes.title = entry.title
                attributes.contentDescription = entry.contentDescription
                if let author = entry.author {
                    attributes.authorNames = [author]
                }
                if let date = entry.publishedDate {
                    attributes.contentCreationDate = date
                }
                attributes.url = entry.url
                attributes.thumbnailURL = entry.thumbnailURL
                if let feedTitle = entry.feedTitle {
                    attributes.containerTitle = feedTitle
                }
                return CSSearchableItem(
                    uniqueIdentifier: entry.identifier,
                    domainIdentifier: domainIdentifier,
                    attributeSet: attributes
                )
            }
            CSSearchableIndex.default().indexSearchableItems(items)
        }
    }

    // MARK: - Removal

    static func removeArticle(id: Int64) {
        let identifiers = [uniqueIdentifier(for: id)]
        Task { @MainActor in
            CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: identifiers)
        }
    }

    static func removeArticles(feedID: Int64, articleIDs: [Int64]) {
        guard !articleIDs.isEmpty else { return }
        let identifiers = articleIDs.map { uniqueIdentifier(for: $0) }
        Task { @MainActor in
            CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: identifiers)
        }
    }

    static func removeAllArticles() {
        Task { @MainActor in
            CSSearchableIndex.default().deleteSearchableItems(
                withDomainIdentifiers: [domainIdentifier]
            )
        }
    }

    // MARK: - Deep Link Parsing

    static func articleID(from userActivity: NSUserActivity) -> Int64? {
        guard let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String
        else { return nil }
        return parseArticleID(from: identifier)
    }

    // MARK: - Helpers

    static func uniqueIdentifier(for articleID: Int64) -> String {
        "article.\(articleID)"
    }

    private static func parseArticleID(from identifier: String) -> Int64? {
        guard identifier.hasPrefix("article.") else { return nil }
        return Int64(identifier.dropFirst("article.".count))
    }

    private static func stripMarkup(_ text: String) -> String? {
        var result = text
        // Remove image placeholders like {{IMG}}https://...{{/IMG}}
        result = result.replacingOccurrences(
            of: "\\{\\{IMG\\}\\}.*?\\{\\{/IMG\\}\\}",
            with: "",
            options: .regularExpression
        )
        // Remove markdown images ![alt](url)
        result = result.replacingOccurrences(
            of: "!\\[[^\\]]*\\]\\([^)]*\\)",
            with: "",
            options: .regularExpression
        )
        // Convert markdown links [text](url) to just text
        result = result.replacingOccurrences(
            of: "\\[([^\\]]+)\\]\\([^)]*\\)",
            with: "$1",
            options: .regularExpression
        )
        // Remove bare URLs
        result = result.replacingOccurrences(
            of: "https?://\\S+",
            with: "",
            options: .regularExpression
        )
        // Strip any remaining HTML tags
        result = result.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )
        // Decode HTML entities
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        // Collapse whitespace
        result = result.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : String(result.prefix(300))
    }

    private static func stripHTML(_ html: String) -> String? {
        var text = html.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : String(text.prefix(300))
    }
}

private struct IndexEntry: Sendable {
    let identifier: String
    let title: String
    let contentDescription: String?
    let author: String?
    let publishedDate: Date?
    let url: URL?
    let thumbnailURL: URL?
    let feedTitle: String?
}
