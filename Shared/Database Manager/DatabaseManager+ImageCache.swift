import Foundation
@preconcurrency import SQLite

nonisolated extension DatabaseManager {

    // MARK: - Image Cache

    func cachedImageData(for url: String) throws -> Data? {
        guard let row = try database.pluck(imageCache.filter(imageCacheURL == url)) else { return nil }
        return row[imageCacheData]
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
}
