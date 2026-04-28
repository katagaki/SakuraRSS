import Foundation

nonisolated struct ParsedFeed: Sendable {
    var title: String
    var siteURL: String
    var description: String
    var articles: [ParsedArticle]
    var hasITunesNamespace: Bool = false
    var generator: String?

    /// Every article in the feed has an audio enclosure.
    var allArticlesHaveAudio: Bool {
        !articles.isEmpty && articles.allSatisfy { $0.audioURL != nil }
    }

    /// At least one article has an audio enclosure, but not all.
    var someArticlesHaveAudio: Bool {
        let audioCount = articles.filter { $0.audioURL != nil }.count
        return audioCount > 0 && audioCount < articles.count
    }

    /// Feed looks like a podcast (all articles have audio, or uses iTunes podcast namespace with audio).
    var isPodcast: Bool {
        allArticlesHaveAudio || (hasITunesNamespace && someArticlesHaveAudio)
    }
}
