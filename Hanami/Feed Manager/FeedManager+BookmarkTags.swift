import Foundation

public extension FeedManager {

    /// Tags are only needed on Bookmarks surfaces, so they are read on demand
    /// keyed by `dataRevision` rather than held in the eager load.
    func bookmarkTagsInUse() -> [(tag: BookmarkTag, count: Int)] {
        (try? database.bookmarkTagsInUse()) ?? []
    }

    func allBookmarkTags() -> [BookmarkTag] {
        (try? database.allBookmarkTags()) ?? []
    }

    func bookmarkTags(forArticleID articleID: Int64) -> [BookmarkTag] {
        (try? database.bookmarkTags(forArticleID: articleID)) ?? []
    }

    func bookmarkedArticles(taggedWith tag: BookmarkTag) -> [Article] {
        (try? database.bookmarkedArticles(taggedWithID: tag.id)) ?? []
    }

    func addBookmarkTag(named name: String, toArticleID articleID: Int64, isAutomatic: Bool = false) {
        try? database.addBookmarkTag(named: name, toArticleID: articleID, isAutomatic: isAutomatic)
        bumpDataRevision()
    }

    func removeBookmarkTag(_ tag: BookmarkTag, fromArticleID articleID: Int64) {
        try? database.removeBookmarkTag(id: tag.id, fromArticleID: articleID)
        bumpDataRevision()
    }

    func renameBookmarkTag(_ tag: BookmarkTag, to name: String) {
        try? database.renameBookmarkTag(id: tag.id, to: name)
        bumpDataRevision()
    }

    func deleteBookmarkTag(_ tag: BookmarkTag) {
        try? database.deleteBookmarkTag(id: tag.id)
        bumpDataRevision()
    }
}
