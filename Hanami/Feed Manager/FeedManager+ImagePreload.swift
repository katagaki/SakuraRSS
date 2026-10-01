import Foundation

public extension FeedManager {

    nonisolated static func preloadImages(urls: [String]) async {
        guard !urls.isEmpty else { return }

        let deduped: [String] = {
            var seen = Set<String>()
            var out: [String] = []
            for url in urls where seen.insert(url).inserted {
                out.append(url)
            }
            return out
        }()

        let database = DatabaseManager.shared
        let candidates: [URL] = deduped.compactMap { urlString in
            guard !urlString.hasPrefix("data:"),
                  let url = URL(string: urlString),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https",
                  !database.isImageCached(for: urlString) else {
                return nil
            }
            return url
        }
        // swiftlint:disable:next line_length
        log("FeedRefresh.ImagePreload", "begin urls=\(urls.count) deduped=\(deduped.count) candidates=\(candidates.count)")
        guard !candidates.isEmpty else { return }

        let maxConcurrent = 4
        var index = 0
        while index < candidates.count {
            if Task.isCancelled { return }
            let batch = candidates[index..<min(index + maxConcurrent, candidates.count)]
            index += maxConcurrent
            await withTaskGroup(of: Void.self) { group in
                for url in batch {
                    group.addTask(priority: .utility) {
                        guard !Task.isCancelled else { return }
                        await downloadAndCacheImage(url: url)
                    }
                }
                for await _ in group where Task.isCancelled {
                    group.cancelAll()
                }
            }
        }
    }

    nonisolated static func backfillRecentImages(
        since cutoff: Date = Date().addingTimeInterval(-14 * 24 * 60 * 60),
        limit: Int = 500
    ) async {
        let database = DatabaseManager.shared
        let articles = (try? database.allArticles(since: cutoff, limit: limit)) ?? []
        let urls = articles.compactMap { $0.imageURL }
        guard !urls.isEmpty else {
            log("ImageBackfill", "no candidate image URLs")
            return
        }
        log("ImageBackfill", "begin candidates=\(urls.count)")
        await preloadImages(urls: urls)
        log("ImageBackfill", "end")
    }

    /// Re-encodes blobs cached before downsampling-on-write existed.
    nonisolated static func shrinkOversizedCachedImages(limit: Int = 300) async {
        let database = DatabaseManager.shared
        let urls = (try? database.cachedImageURLs(largerThan: 512 * 1024, limit: limit)) ?? []
        guard !urls.isEmpty else { return }
        var savedBytes = 0
        var shrunkCount = 0
        for urlString in urls {
            if Task.isCancelled { break }
            guard let original = try? database.cachedImageData(for: urlString) else { continue }
            let shrunk = ImageDownsampler.cacheableData(original)
            if shrunk.count < original.count {
                try? database.replaceCachedImageData(shrunk, for: urlString)
                savedBytes += original.count - shrunk.count
                shrunkCount += 1
            }
            await Task.yield()
        }
        log("ImageBackfill", "shrunk \(shrunkCount)/\(urls.count) cached images saved=\(savedBytes) bytes")
    }

    nonisolated private static func downloadAndCacheImage(url: URL) async {
        let urlString = url.absoluteString
        let database = DatabaseManager.shared
        if database.isImageCached(for: urlString) { return }
        do {
            let (data, response) = try await URLSession.sakuraImages.data(for: .sakuraImage(url: url))
            if let http = response as? HTTPURLResponse,
               !(200..<300).contains(http.statusCode) {
                log("FeedRefresh.ImagePreload", "fail url=\(urlString) status=\(http.statusCode)")
                return
            }
            guard !data.isEmpty else {
                log("FeedRefresh.ImagePreload", "fail url=\(urlString) reason=empty")
                return
            }
            let cacheable = ImageDownsampler.cacheableData(data)
            try? database.cacheImageData(cacheable, for: urlString)
            log("FeedRefresh.ImagePreload", "success url=\(urlString) bytes=\(data.count) stored=\(cacheable.count)")
        } catch {
            log("FeedRefresh.ImagePreload", "fail url=\(urlString) error=\(error.localizedDescription)")
        }
    }
}
