import Foundation

public nonisolated struct ParsedFeed: Sendable {
    public var title: String
    public var siteURL: String
    public var description: String
    public var articles: [ParsedArticle]
    public var hasITunesNamespace: Bool = false
    public var generator: String?

    /// Every article in the feed has an audio enclosure.
    public var allArticlesHaveAudio: Bool {
        !articles.isEmpty && articles.allSatisfy { $0.audioURL != nil }
    }

    /// At least one article has an audio enclosure, but not all.
    public var someArticlesHaveAudio: Bool {
        let audioCount = articles.filter { $0.audioURL != nil }.count
        return audioCount > 0 && audioCount < articles.count
    }

    /// Feed looks like a podcast (all articles have audio, or uses iTunes podcast namespace with audio).
    public var isPodcast: Bool {
        allArticlesHaveAudio || (hasITunesNamespace && someArticlesHaveAudio)
    }
}
