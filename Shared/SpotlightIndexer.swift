import CoreSpotlight
import Foundation

enum SpotlightIndexer {

    static let domainIdentifier = "com.tsubuzaki.SakuraRSS.article"

    // MARK: - Indexing

    static func indexArticles(_ articles: [Article], feedTitle: String?) {
        guard !articles.isEmpty else { return }

        let items = articles.compactMap { article -> CSSearchableItem? in
            let attributes = CSSearchableItemAttributeSet(contentType: .text)
            attributes.title = article.title
            attributes.contentDescription = article.summary ?? article.content.flatMap { stripHTML($0) }
            if let author = article.author {
                attributes.authorNames = [author]
            }
            if let date = article.publishedDate {
                attributes.contentCreationDate = date
            }
            if let urlString = URL(string: article.url) {
                attributes.url = urlString
            }
            if let imageURLString = article.imageURL, let imageURL = URL(string: imageURLString) {
                attributes.thumbnailURL = imageURL
            }
            if let feedTitle {
                attributes.containerTitle = feedTitle
            }
            return CSSearchableItem(
                uniqueIdentifier: uniqueIdentifier(for: article.id),
                domainIdentifier: domainIdentifier,
                attributeSet: attributes
            )
        }

        CSSearchableIndex.default().indexSearchableItems(items)
    }

    // MARK: - Removal

    static func removeArticle(id: Int64) {
        CSSearchableIndex.default().deleteSearchableItems(
            withIdentifiers: [uniqueIdentifier(for: id)]
        )
    }

    static func removeArticles(feedID: Int64, articleIDs: [Int64]) {
        guard !articleIDs.isEmpty else { return }
        let identifiers = articleIDs.map { uniqueIdentifier(for: $0) }
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: identifiers)
    }

    static func removeAllArticles() {
        CSSearchableIndex.default().deleteSearchableItems(
            withDomainIdentifiers: [domainIdentifier]
        )
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
