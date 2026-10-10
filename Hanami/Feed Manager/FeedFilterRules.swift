import Foundation

public struct FeedFilterRules: Sendable {
    public let allowedKeywords: [String]
    public let keywords: [String]
    public let authors: Set<String>

    nonisolated init(allowedKeywords: [String], keywords: [String], authors: Set<String>) {
        self.allowedKeywords = allowedKeywords
        self.keywords = keywords
        self.authors = authors
    }

    nonisolated init(grouped: [String: [String]]) {
        self.init(
            allowedKeywords: grouped["allowed_keyword"] ?? [],
            keywords: grouped["muted_keyword"] ?? [],
            authors: Set(grouped["muted_author"] ?? [])
        )
    }

    nonisolated var isEmpty: Bool {
        allowedKeywords.isEmpty && keywords.isEmpty && authors.isEmpty
    }
}
