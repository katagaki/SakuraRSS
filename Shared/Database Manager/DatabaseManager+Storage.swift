import Foundation
@preconcurrency import SQLite

nonisolated extension DatabaseManager {

    /// Approximate on-disk byte usage of stored content per feed, summing the
    /// length of all text columns on `articles` and the bytes of any matching
    /// rows in `image_cache` keyed by article image URL.
    func storageSizeByFeed() throws -> [Int64: Int64] {
        var sizes: [Int64: Int64] = [:]

        let articleSQL = """
            SELECT feed_id,
                   SUM(
                       COALESCE(LENGTH(title), 0) +
                       COALESCE(LENGTH(url), 0) +
                       COALESCE(LENGTH(author), 0) +
                       COALESCE(LENGTH(summary), 0) +
                       COALESCE(LENGTH(content), 0) +
                       COALESCE(LENGTH(image_url), 0) +
                       COALESCE(LENGTH(carousel_urls), 0) +
                       COALESCE(LENGTH(audio_url), 0) +
                       COALESCE(LENGTH(ai_summary), 0) +
                       COALESCE(LENGTH(translated_title), 0) +
                       COALESCE(LENGTH(translated_text), 0) +
                       COALESCE(LENGTH(translated_summary), 0) +
                       COALESCE(LENGTH(transcript_json), 0) +
                       COALESCE(LENGTH(download_path), 0)
                   ) AS bytes
            FROM articles
            GROUP BY feed_id
            """

        for row in try database.prepare(articleSQL) {
            guard let feedID = row[0] as? Int64 else { continue }
            let bytes = (row[1] as? Int64) ?? Int64((row[1] as? Double) ?? 0)
            sizes[feedID, default: 0] += bytes
        }

        let imageSQL = """
            SELECT a.feed_id, SUM(LENGTH(ic.data)) AS bytes
            FROM articles a
            INNER JOIN image_cache ic ON ic.url = a.image_url
            GROUP BY a.feed_id
            """

        for row in try database.prepare(imageSQL) {
            guard let feedID = row[0] as? Int64 else { continue }
            let bytes = (row[1] as? Int64) ?? Int64((row[1] as? Double) ?? 0)
            sizes[feedID, default: 0] += bytes
        }

        let iconSQL = """
            SELECT f.id, LENGTH(ic.data) AS bytes
            FROM feeds f
            INNER JOIN image_cache ic ON ic.url = f.favicon_url
            """

        for row in try database.prepare(iconSQL) {
            guard let feedID = row[0] as? Int64 else { continue }
            let bytes = (row[1] as? Int64) ?? Int64((row[1] as? Double) ?? 0)
            sizes[feedID, default: 0] += bytes
        }

        let commentsSQL = """
            SELECT a.feed_id,
                   SUM(COALESCE(LENGTH(c.author), 0)
                       + COALESCE(LENGTH(c.body), 0)
                       + COALESCE(LENGTH(c.source_url), 0)) AS bytes
            FROM comments c
            INNER JOIN articles a ON a.id = c.article_id
            GROUP BY a.feed_id
            """

        for row in try database.prepare(commentsSQL) {
            guard let feedID = row[0] as? Int64 else { continue }
            let bytes = (row[1] as? Int64) ?? Int64((row[1] as? Double) ?? 0)
            sizes[feedID, default: 0] += bytes
        }

        let entitiesSQL = """
            SELECT a.feed_id,
                   SUM(COALESCE(LENGTH(ne.name), 0)
                       + COALESCE(LENGTH(ne.type), 0)) AS bytes
            FROM nlp_entities ne
            INNER JOIN articles a ON a.id = ne.article_id
            GROUP BY a.feed_id
            """

        for row in try database.prepare(entitiesSQL) {
            guard let feedID = row[0] as? Int64 else { continue }
            let bytes = (row[1] as? Int64) ?? Int64((row[1] as? Double) ?? 0)
            sizes[feedID, default: 0] += bytes
        }

        let similarSQL = """
            SELECT a.feed_id, COUNT(*) * 24 AS bytes
            FROM similar_articles sa
            INNER JOIN articles a ON a.id = sa.source_id
            GROUP BY a.feed_id
            """

        for row in try database.prepare(similarSQL) {
            guard let feedID = row[0] as? Int64 else { continue }
            let bytes = (row[1] as? Int64) ?? Int64((row[1] as? Double) ?? 0)
            sizes[feedID, default: 0] += bytes
        }

        for (feedID, bytes) in podcastDownloadSizesByFeed() {
            sizes[feedID, default: 0] += bytes
        }

        return sizes
    }

    /// Sums podcast download file sizes per feed by mapping each episode
    /// directory back to its article via the `articles.download_path` column.
    private func podcastDownloadSizesByFeed() -> [Int64: Int64] {
        let fileManager = FileManager.default
        guard let container = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.SakuraRSS"
        ) else { return [:] }
        let root = container.appendingPathComponent("PodcastDownloads", isDirectory: true)
        guard fileManager.fileExists(atPath: root.path) else { return [:] }
        var bytesByArticleID: [Int64: Int64] = [:]
        let entries = (try? fileManager.contentsOfDirectory(atPath: root.path)) ?? []
        for name in entries {
            guard let articleID = Int64(name) else { continue }
            let dir = root.appendingPathComponent(name, isDirectory: true)
            bytesByArticleID[articleID] = directoryFilesSize(at: dir)
        }
        guard !bytesByArticleID.isEmpty else { return [:] }
        let sql = "SELECT id, feed_id FROM articles WHERE id IN (\(bytesByArticleID.keys.map { "\($0)" }.joined(separator: ",")))"
        var perFeed: [Int64: Int64] = [:]
        if let rows = try? database.prepare(sql) {
            for row in rows {
                guard let articleID = row[0] as? Int64,
                      let feedID = row[1] as? Int64,
                      let bytes = bytesByArticleID[articleID] else { continue }
                perFeed[feedID, default: 0] += bytes
            }
        }
        return perFeed
    }

    private func directoryFilesSize(at url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
        ) else { return 0 }
        var total: Int64 = 0
        for case let entry as URL in enumerator {
            if let values = try? entry.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
               values.isRegularFile == true,
               let size = values.fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    /// Total byte size of the `Sakura.feeds` SQLite database file plus its WAL
    /// and shared-memory companions when present.
    func totalDatabaseSizeOnDisk() -> Int64 {
        let path = Self.databasePath
        let companions = [path, path + "-wal", path + "-shm"]
        var total: Int64 = 0
        for companion in companions {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: companion),
               let size = attributes[.size] as? Int64 {
                total += size
            } else if let attributes = try? FileManager.default.attributesOfItem(atPath: companion),
                      let size = attributes[.size] as? NSNumber {
                total += size.int64Value
            }
        }
        return total
    }

    /// Sum of bytes stored in the `image_cache` table — the in-database BLOB
    /// portion of the on-disk image footprint.
    func imageCacheTableSize() -> Int64 {
        let sql = "SELECT COALESCE(SUM(LENGTH(data)), 0) FROM image_cache"
        guard let row = try? database.prepare(sql).makeIterator().next() else { return 0 }
        return (row[0] as? Int64) ?? Int64((row[0] as? Double) ?? 0)
    }
}

/// Byte breakdown of Sakura's on-disk footprint by category.
nonisolated struct SakuraStorageBreakdown: Sendable {
    let feedsBytes: Int64
    let podcastsBytes: Int64
    let cacheBytes: Int64

    var totalBytes: Int64 { feedsBytes + podcastsBytes + cacheBytes }
}

/// Splits the shared app-group container into Feeds (DB text + recipes),
/// Podcasts (downloaded audio), and Cache (DB image cache + favicon cache +
/// widget thumbnails).
nonisolated func sakuraStorageBreakdown(imageCacheTableBytes: Int64) -> SakuraStorageBreakdown {
    guard let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.SakuraRSS"
    ) else {
        return SakuraStorageBreakdown(feedsBytes: 0, podcastsBytes: 0, cacheBytes: 0)
    }
    let podcasts = directorySize(at: container.appendingPathComponent("PodcastDownloads", isDirectory: true))
    let favicons = directorySize(at: container.appendingPathComponent("FaviconCache", isDirectory: true))
    let widgetThumbs = directorySize(at: container.appendingPathComponent("WidgetThumbnails", isDirectory: true))
    let containerTotal = directorySize(at: container)
    let cacheOnDisk = favicons + widgetThumbs
    let cache = imageCacheTableBytes + cacheOnDisk
    let feeds = max(0, containerTotal - podcasts - cacheOnDisk - imageCacheTableBytes)
    return SakuraStorageBreakdown(
        feedsBytes: feeds,
        podcastsBytes: podcasts,
        cacheBytes: cache
    )
}

private nonisolated func directorySize(at url: URL) -> Int64 {
    guard let enumerator = FileManager.default.enumerator(
        at: url,
        includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
    ) else { return 0 }
    var total: Int64 = 0
    for case let entry as URL in enumerator {
        if let values = try? entry.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
           values.isRegularFile == true,
           let size = values.fileSize {
            total += Int64(size)
        }
    }
    return total
}
