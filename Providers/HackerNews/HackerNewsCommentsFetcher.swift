import Foundation

/// Fetches top-ranked Hacker News comments for an article via the public
/// Firebase API. Conforms to `CommentSource` so the article viewer can
/// surface comments alongside other providers.
nonisolated enum HackerNewsCommentsFetcher: CommentSource {

    static var providerID: String { "hacker_news" }

    static func canProvideComments(for article: Article, in feed: Feed?) -> Bool {
        commentsURL(for: article, in: feed) != nil
    }

    static func commentsURL(for article: Article, in feed: Feed?) -> URL? {
        if let feed, !feed.isHackerNewsFeed { return nil }
        if let summary = article.summary,
           let url = HackerNewsProvider.threadURL(fromSummary: summary) {
            return url
        }
        if let url = URL(string: article.url),
           let host = url.host?.lowercased(),
           host == HackerNewsProvider.host || host.hasSuffix(".\(HackerNewsProvider.host)"),
           HackerNewsProvider.threadID(from: url) != nil {
            return url
        }
        return nil
    }

    static func fetchComments(
        for article: Article, in feed: Feed?, limit: Int
    ) async throws -> [FetchedComment] {
        guard limit > 0,
              let threadURL = commentsURL(for: article, in: feed),
              let threadID = HackerNewsProvider.threadID(from: threadURL),
              let storyURL = URL(
                string: "https://hacker-news.firebaseio.com/v0/item/\(threadID).json"
              ) else {
            log("Comments", "HN fetchComments aborted (no thread URL/ID) article id=\(article.id)")
            return []
        }
        log("Comments", "HN story fetch begin thread=\(threadID)")

        let story = try await fetchItem(at: storyURL)
        guard let kids = story.kids, !kids.isEmpty else {
            log("Comments", "HN story has no kids thread=\(threadID)")
            return []
        }
        let topKids = Array(kids.prefix(limit))
        log("Comments", "HN story ok thread=\(threadID) totalKids=\(kids.count) takingTop=\(topKids.count)")

        let results: [FetchedComment] = await withTaskGroup(
            of: (Int, FetchedComment?).self
        ) { group in
            for (rank, kidID) in topKids.enumerated() {
                group.addTask {
                    let comment = await fetchComment(id: kidID)
                    return (rank, comment)
                }
            }
            var collected = [FetchedComment?](repeating: nil, count: topKids.count)
            for await (rank, comment) in group where rank < collected.count {
                collected[rank] = comment
            }
            return collected.compactMap { $0 }
        }
        log("Comments", "HN comments fetched thread=\(threadID) usable=\(results.count)/\(topKids.count)")
        return results
    }

    private static func fetchComment(id: Int) async -> FetchedComment? {
        guard let url = URL(
            string: "https://hacker-news.firebaseio.com/v0/item/\(id).json"
        ) else { return nil }
        let item: HackerNewsFirebaseItem
        do {
            item = try await fetchItem(at: url)
        } catch {
            log("Comments", "HN comment fetch failed id=\(id) error=\(error)")
            return nil
        }
        if item.deleted == true || item.dead == true {
            log("Comments", "HN comment skipped (deleted/dead) id=\(id)")
            return nil
        }
        guard let body = item.text, !body.isEmpty else {
            log("Comments", "HN comment skipped (empty text) id=\(id)")
            return nil
        }
        let cleaned = HackerNewsCommentText.clean(body)
        log("Comments", "HN comment ok id=\(id) author=\(item.by ?? "?") chars=\(cleaned.count)")
        return FetchedComment(
            author: item.by ?? "",
            body: cleaned,
            createdDate: item.time.map { Date(timeIntervalSince1970: $0) },
            sourceURL: "https://news.ycombinator.com/item?id=\(id)"
        )
    }

    private static func fetchItem(at url: URL) async throws -> HackerNewsFirebaseItem {
        let request = URLRequest.sakura(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        log("Comments", "HN GET \(url.absoluteString) status=\(status) bytes=\(data.count)")
        return try JSONDecoder().decode(HackerNewsFirebaseItem.self, from: data)
    }
}

nonisolated struct HackerNewsFirebaseItem: Decodable, Sendable {
    let id: Int
    // swiftlint:disable:next identifier_name
    let by: String?
    let text: String?
    let time: TimeInterval?
    let kids: [Int]?
    let deleted: Bool?
    let dead: Bool?
    let type: String?
}
