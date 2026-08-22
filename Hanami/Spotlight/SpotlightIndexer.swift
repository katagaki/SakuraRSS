import CoreSpotlight
import Foundation

public nonisolated enum SpotlightIndexer {

    public static let domainIdentifier = "com.tsubuzaki.SakuraRSS.article"

    /// Bump to trigger a one-time full reindex on next launch when attribute shape changes.
    public static let schemaVersion: Int = 1

    public static let schemaVersionDefaultsKey = "App.SpotlightIndexVersion"

    // MARK: - Indexing

    public static func indexArticles(_ articles: [Article], feedTitle: String?) {
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

        Task.detached(priority: .utility) {
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
            try? await CSSearchableIndex.default().indexSearchableItems(items)
        }
    }

    // MARK: - Removal

    public static func removeArticle(id: Int64) {
        let identifiers = [uniqueIdentifier(for: id)]
        Task.detached(priority: .utility) {
            try? await CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: identifiers)
        }
    }

    public static func removeArticles(feedID: Int64, articleIDs: [Int64]) {
        guard !articleIDs.isEmpty else { return }
        let identifiers = articleIDs.map { uniqueIdentifier(for: $0) }
        Task.detached(priority: .utility) {
            try? await CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: identifiers)
        }
    }

    public static func removeAllArticles() {
        Task.detached(priority: .utility) {
            try? await CSSearchableIndex.default().deleteSearchableItems(
                withDomainIdentifiers: [domainIdentifier]
            )
        }
    }

    // MARK: - Deep Link Parsing

    public static func articleID(from userActivity: NSUserActivity) -> Int64? {
        guard let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String
        else { return nil }
        return parseArticleID(from: identifier)
    }
    public static func uniqueIdentifier(for articleID: Int64) -> String {
        "article.\(articleID)"
    }

    private static func parseArticleID(from identifier: String) -> Int64? {
        guard identifier.hasPrefix("article.") else { return nil }
        return Int64(identifier.dropFirst("article.".count))
    }

    private static func stripMarkup(_ text: String) -> String? {
        var result = text
        result = replacingMatches(result, imageMarkerExpression, with: "")
        result = replacingMatches(result, markdownImageExpression, with: "")
        result = replacingMatches(result, markdownLinkExpression, with: "$1")
        result = replacingMatches(result, bareURLExpression, with: "")
        result = replacingMatches(result, htmlTagExpression, with: " ")
        result = decodingEntities(result)
        result = replacingMatches(result, whitespaceRunExpression, with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : String(result.prefix(300))
    }

    private static func stripHTML(_ html: String) -> String? {
        var text = replacingMatches(html, htmlTagExpression, with: " ")
        text = decodingEntities(text)
        text = replacingMatches(text, whitespaceRunExpression, with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
