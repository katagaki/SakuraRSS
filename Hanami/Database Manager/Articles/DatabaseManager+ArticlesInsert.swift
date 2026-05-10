import Foundation
@preconcurrency import SQLite

public nonisolated struct ArticleInsertData: Sendable {
    public var author: String?
    public var summary: String?
    public var content: String?
    public var imageURL: String?
    public var carouselImageURLs: [String] = []
    public var publishedDate: Date?
    public var audioURL: String?
    public var duration: Int?

    public init(
        author: String? = nil,
        summary: String? = nil,
        content: String? = nil,
        imageURL: String? = nil,
        carouselImageURLs: [String] = [],
        publishedDate: Date? = nil,
        audioURL: String? = nil,
        duration: Int? = nil
    ) {
        self.author = author
        self.summary = summary
        self.content = content
        self.imageURL = imageURL
        self.carouselImageURLs = carouselImageURLs
        self.publishedDate = publishedDate
        self.audioURL = audioURL
        self.duration = duration
    }
}

public nonisolated struct ArticleInsertItem: Sendable {
    public var title: String
    public var url: String
    public var data: ArticleInsertData

    public init(title: String, url: String, data: ArticleInsertData) {
        self.title = title
        self.url = url
        self.data = data
    }
}

public nonisolated extension DatabaseManager {

    @discardableResult
    func insertArticle(
        feedID fid: Int64,
        title: String,
        url: String,
        data: ArticleInsertData = ArticleInsertData()
    ) throws -> Int64 {
        let carouselValue = data.carouselImageURLs.isEmpty
            ? nil : data.carouselImageURLs.joined(separator: "\n")
        return try database.run(articles.insert(or: .ignore,
            articleFeedID <- fid,
            articleTitle <- title,
            articleURL <- url,
            articleAuthor <- data.author,
            articleSummary <- data.summary,
            articleContent <- data.content,
            articleImageURL <- data.imageURL,
            articleCarouselURLs <- carouselValue,
            articlePublishedDate <- data.publishedDate?.timeIntervalSince1970,
            articleIsRead <- false,
            articleIsBookmarked <- false,
            articleAudioURL <- data.audioURL,
            articleDuration <- data.duration
        ))
    }

    @discardableResult
    func insertArticles(feedID fid: Int64, articles items: [ArticleInsertItem]) throws -> [Int64] {
        guard !items.isEmpty else { return [] }
        let cutoffDate = articleCutoffDate()
        var insertedIDs: [Int64] = []
        try database.transaction {
            insertedIDs = try insertArticleItems(feedID: fid, items: items, cutoffDate: cutoffDate)
        }
        return insertedIDs
    }

    private func articleCutoffDate() -> Date? {
        let cutoffTimestamp = UserDefaults.standard.double(forKey: "Content.CutoffDate")
        return cutoffTimestamp > 0 ? Date(timeIntervalSince1970: cutoffTimestamp) : nil
    }

    private func insertArticleItems(
        feedID fid: Int64,
        items: [ArticleInsertItem],
        cutoffDate: Date?
    ) throws -> [Int64] {
        var insertedIDs: [Int64] = []
        for item in items {
            if let cutoff = cutoffDate, let published = item.data.publishedDate,
               published < cutoff {
                continue
            }
            let carouselValue = item.data.carouselImageURLs.isEmpty
                ? nil : item.data.carouselImageURLs.joined(separator: "\n")
            let rowid = try database.run(articles.insert(or: .ignore,
                articleFeedID <- fid,
                articleTitle <- item.title,
                articleURL <- item.url,
                articleAuthor <- item.data.author,
                articleSummary <- item.data.summary,
                articleContent <- item.data.content,
                articleImageURL <- item.data.imageURL,
                articleCarouselURLs <- carouselValue,
                articlePublishedDate <- item.data.publishedDate?.timeIntervalSince1970,
                articleIsRead <- false,
                articleIsBookmarked <- false,
                articleAudioURL <- item.data.audioURL,
                articleDuration <- item.data.duration
            ))
            if database.changes > 0 {
                insertedIDs.append(rowid)
            }
        }
        return insertedIDs
    }
}
