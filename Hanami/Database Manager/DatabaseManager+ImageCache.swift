import Foundation
@preconcurrency import SQLite

/// Dedicated connection for image blobs: multi-megabyte reads/writes during
/// scrolling would otherwise serialize main-thread article queries on the
/// shared connection's mutex. WAL mode allows the concurrent reader/writer
/// pair, and lazy creation keeps it pointing at the restored file when an
/// onboarding restore swaps the database before any image is loaded.
private nonisolated(unsafe) let imageCacheConnection: Connection? = {
    guard let connection = try? Connection(DatabaseManager.databasePath) else { return nil }
    _ = try? connection.run("PRAGMA journal_mode = WAL")
    _ = try? connection.run("PRAGMA synchronous = NORMAL")
    connection.busyTimeout = 5.0
    return connection
}()

public nonisolated extension DatabaseManager {

    private var imageDatabase: Connection {
        imageCacheConnection ?? database
    }

    // MARK: - Image Cache

    func cachedImageData(for url: String) throws -> Data? {
        guard let row = try imageDatabase.pluck(imageCache.filter(imageCacheURL == url)) else { return nil }
        return row[imageCacheData]
    }

    /// Cheap existence check that avoids loading the full BLOB.
    func isImageCached(for url: String) -> Bool {
        guard let row = try? imageDatabase.pluck(
            imageCache.select(imageCacheURL).filter(imageCacheURL == url)
        ) else { return false }
        return row[imageCacheURL] == url
    }

    func cacheImageData(_ data: Data, for url: String) throws {
        try imageDatabase.run(imageCache.insert(or: .replace,
            imageCacheURL <- url,
            imageCacheData <- data,
            imageCachedAt <- Date().timeIntervalSince1970
        ))
    }

    func clearCachedImageData(for url: String) throws {
        try imageDatabase.run(imageCache.filter(imageCacheURL == url).delete())
    }

    func clearImageCache() throws {
        try imageDatabase.run(imageCache.delete())
    }

    func clearImageCache(olderThan date: Date) throws {
        let target = imageCache.filter(imageCachedAt < date.timeIntervalSince1970)
        try imageDatabase.run(target.delete())
    }
}
