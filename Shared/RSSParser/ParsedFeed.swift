import Foundation

nonisolated struct ParsedFeed: Sendable {
    var title: String
    var siteURL: String
    var description: String
    var articles: [ParsedArticle]

    /// Every article in the feed has an audio enclosure.
    var allArticlesHaveAudio: Bool {
        !articles.isEmpty && articles.allSatisfy { $0.audioURL != nil }
    }

    /// At least one article has an audio enclosure, but not all.
    var someArticlesHaveAudio: Bool {
        let audioCount = articles.filter { $0.audioURL != nil }.count
        return audioCount > 0 && audioCount < articles.count
    }
}
