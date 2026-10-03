import Foundation
@preconcurrency import SQLite

public nonisolated extension DatabaseManager {

    // MARK: - Tag CRUD

    /// Returns the id of the tag with this name, inserting it when new.
    /// Names are matched case-insensitively so "swift" and "Swift" stay one tag.
    @discardableResult
    func bookmarkTagID(named name: String, isAutomatic: Bool = false) throws -> Int64? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = BookmarkTag.normalized(trimmed)
        if let existing = try database.pluck(bookmarkTags.filter(bookmarkTagNormalizedName == normalized)) {
            return existing[bookmarkTagID]
        }
        return try database.run(bookmarkTags.insert(
            bookmarkTagName <- trimmed,
            bookmarkTagNormalizedName <- normalized,
            bookmarkTagIsAutomatic <- isAutomatic
        ))
    }

    func allBookmarkTags() throws -> [BookmarkTag] {
        try database.prepare(bookmarkTags.order(bookmarkTagName.asc)).map(rowToBookmarkTag)
    }

    /// Tags applied to at least one bookmark, most used first.
    func bookmarkTagsInUse() throws -> [(tag: BookmarkTag, count: Int)] {
        let counts = try bookmarkTagCounts()
        var result: [(tag: BookmarkTag, count: Int)] = []
        for tag in try allBookmarkTags() {
            guard let count = counts[tag.id], count > 0 else { continue }
            result.append((tag: tag, count: count))
        }
        result.sort { first, second in
            if first.count != second.count { return first.count > second.count }
            return first.tag.name.localizedStandardCompare(second.tag.name) == .orderedAscending
        }
        return result
    }

    func renameBookmarkTag(id: Int64, to name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try database.run(bookmarkTags.filter(bookmarkTagID == id).update(
            bookmarkTagName <- trimmed,
            bookmarkTagNormalizedName <- BookmarkTag.normalized(trimmed),
            bookmarkTagIsAutomatic <- false
        ))
    }

    func deleteBookmarkTag(id: Int64) throws {
        try database.run(bookmarkTagItems.filter(bookmarkTagItemTagID == id).delete())
        try database.run(bookmarkTags.filter(bookmarkTagID == id).delete())
    }

    // MARK: - Membership

    func addBookmarkTag(named name: String, toArticleID aid: Int64, isAutomatic: Bool = false) throws {
        guard let tagID = try bookmarkTagID(named: name, isAutomatic: isAutomatic) else { return }
        try database.run(bookmarkTagItems.insert(
            or: .ignore,
            bookmarkTagItemTagID <- tagID,
            bookmarkTagItemArticleID <- aid
        ))
    }

    func removeBookmarkTag(id: Int64, fromArticleID aid: Int64) throws {
        try database.run(
            bookmarkTagItems
                .filter(bookmarkTagItemTagID == id && bookmarkTagItemArticleID == aid)
                .delete()
        )
        try deleteAutomaticBookmarkTagIfUnused(id: id)
    }

    func bookmarkTags(forArticleID aid: Int64) throws -> [BookmarkTag] {
        let ids = try database.prepare(
            bookmarkTagItems.filter(bookmarkTagItemArticleID == aid).select(bookmarkTagItemTagID)
        ).map { $0[bookmarkTagItemTagID] }
        guard !ids.isEmpty else { return [] }
        return try database.prepare(
            bookmarkTags.filter(ids.contains(bookmarkTagID)).order(bookmarkTagName.asc)
        ).map(rowToBookmarkTag)
    }

    func bookmarkedArticles(taggedWithID tagID: Int64) throws -> [Article] {
        let ids = try database.prepare(
            bookmarkTagItems.filter(bookmarkTagItemTagID == tagID).select(bookmarkTagItemArticleID)
        ).map { $0[bookmarkTagItemArticleID] }
        guard !ids.isEmpty else { return [] }
        let query = selectingListColumns(articles)
            .filter(ids.contains(articleID) && articleIsBookmarked == true)
            .order(articlePublishedDate.desc)
        return try database.prepare(query).map(rowToListArticle)
    }

    // MARK: - Maintenance

    func bookmarkTagCounts() throws -> [Int64: Int] {
        var counts: [Int64: Int] = [:]
        for row in try database.prepare(bookmarkTagItems.select(bookmarkTagItemTagID)) {
            counts[row[bookmarkTagItemTagID], default: 0] += 1
        }
        return counts
    }

    /// Automatic tags exist to keep a library browsable, not to accumulate.
    /// Once nothing carries one any more it goes away; hand-made tags stay.
    func deleteAutomaticBookmarkTagIfUnused(id: Int64) throws {
        guard let row = try database.pluck(bookmarkTags.filter(bookmarkTagID == id)),
              row[bookmarkTagIsAutomatic] else { return }
        let remaining = try database.scalar(bookmarkTagItems.filter(bookmarkTagItemTagID == id).count)
        if remaining == 0 {
            try database.run(bookmarkTags.filter(bookmarkTagID == id).delete())
        }
    }

    /// Drops tag links whose article was deleted or is no longer bookmarked.
    func pruneOrphanedBookmarkTagItems() throws {
        try database.run("""
            DELETE FROM bookmark_tag_items WHERE article_id NOT IN \
            (SELECT id FROM articles WHERE is_bookmarked = 1)
            """)
        try database.run("""
            DELETE FROM bookmark_tags WHERE is_automatic = 1 AND id NOT IN \
            (SELECT tag_id FROM bookmark_tag_items)
            """)
    }

    // MARK: - Row Mapping

    func rowToBookmarkTag(_ row: Row) -> BookmarkTag {
        BookmarkTag(
            id: row[bookmarkTagID],
            name: row[bookmarkTagName],
            isAutomatic: row[bookmarkTagIsAutomatic]
        )
    }
}
