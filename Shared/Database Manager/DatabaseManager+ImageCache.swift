import Foundation
@preconcurrency import SQLite

nonisolated extension DatabaseManager {

    // MARK: - Image Cache

    func cachedImageData(for url: String) throws -> Data? {
        guard let row = try database.pluck(imageCache.filter(imageCacheURL == url)) else { return nil }
        return row[imageCacheData]
    }

    /// Cheap existence check that avoids loading the full BLOB.
    func isImageCached(for url: String) -> Bool {
        guard let row = try? database.pluck(
            imageCache.select(imageCacheURL).filter(imageCacheURL == url)
        ) else { return false }
        return row[imageCacheURL] == url
    }

    func cacheImageData(_ data: Data, for url: String) throws {
        try database.run(imageCache.insert(or: .replace,
            imageCacheURL <- url,
            imageCacheData <- data,
            imageCachedAt <- Date().timeIntervalSince1970
        ))
    }

    func clearCachedImageData(for url: String) throws {
        try database.run(imageCache.filter(imageCacheURL == url).delete())
    }

    func clearImageCache() throws {
        try database.run(imageCache.delete())
    }

    func clearImageCache(olderThan date: Date) throws {
        let target = imageCache.filter(imageCachedAt < date.timeIntervalSince1970)
        try database.run(target.delete())
    }
}
