import Foundation
@preconcurrency import SQLite

public nonisolated extension DatabaseManager {

    /// Bookmarks with no image yet whose preview lookup has not been tried.
    func bookmarkIDsNeedingPreview(limit: Int = 25) throws -> [(id: Int64, url: String)] {
        let query = articles
            .filter(articleIsBookmarked == true && articleImageURL == nil)
            .order(articlePublishedDate.desc)
            .limit(limit)
            .select(articleID, articleURL, articlePreviewFetchState)
        return try database.prepare(query).compactMap { row in
            let state = (try? row.get(articlePreviewFetchState)) ?? 0
            guard state == BookmarkPreviewFetchState.notAttempted.rawValue else { return nil }
            let url = row[articleURL]
            guard !url.isEmpty else { return nil }
            return (id: row[articleID], url: url)
        }
    }

    func setBookmarkPreview(
        imageURL: String?,
        state: BookmarkPreviewFetchState,
        forArticleID aid: Int64
    ) throws {
        let target = articles.filter(articleID == aid)
        if let imageURL {
            try database.run(target.update(
                articleImageURL <- imageURL,
                articlePreviewFetchState <- state.rawValue,
                articlePreviewFetchedAt <- Date().timeIntervalSince1970
            ))
        } else {
            try database.run(target.update(
                articlePreviewFetchState <- state.rawValue,
                articlePreviewFetchedAt <- Date().timeIntervalSince1970
            ))
        }
    }

    /// Clears the "already tried" mark so a manual refresh can look again.
    func resetBookmarkPreviewState(forArticleID aid: Int64) throws {
        try database.run(articles.filter(articleID == aid).update(
            articlePreviewFetchState <- BookmarkPreviewFetchState.notAttempted.rawValue
        ))
    }
}
