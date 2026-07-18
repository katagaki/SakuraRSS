import Foundation
@preconcurrency import SQLite

public nonisolated extension DatabaseManager {

    /// Saves an externally shared link into Bookmarks. Reuses an existing
    /// article row when the URL is already known, otherwise inserts a
    /// feed-less article dated now so it surfaces at the top of Bookmarks.
    @discardableResult
    func insertExternalBookmark(url: String, title: String, folderID: Int64?) throws -> Int64 {
        let articleRowID: Int64
        if let existing = try database.pluck(articles.filter(articleURL == url)) {
            let id = existing[articleID]
            try database.run(articles.filter(articleID == id).update(
                articleIsBookmarked <- true,
                articleExternalSource <- true
            ))
            articleRowID = id
        } else {
            articleRowID = try database.run(articles.insert(
                articleFeedID <- 0,
                articleTitle <- title,
                articleURL <- url,
                articleIsRead <- false,
                articleIsBookmarked <- true,
                articleExternalSource <- true,
                articlePublishedDate <- Date().timeIntervalSince1970
            ))
        }
        if let folderID {
            try setBookmarkFolder(articleID: articleRowID, folderID: folderID)
        }
        return articleRowID
    }
}
