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

    /// Best-effort backfill of cached images for recently published articles.
    /// `preloadImages` skips anything already cached, so this only fetches gaps.
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

    nonisolated private static func downloadAndCacheImage(url: URL) async {
        let urlString = url.absoluteString
        let database = DatabaseManager.shared
        if database.isImageCached(for: urlString) { return }
        do {
            let (data, response) = try await URLSession.shared.data(for: .sakuraImage(url: url))
            if let http = response as? HTTPURLResponse,
               !(200..<300).contains(http.statusCode) {
                log("FeedRefresh.ImagePreload", "fail url=\(urlString) status=\(http.statusCode)")
                return
            }
            guard !data.isEmpty else {
                log("FeedRefresh.ImagePreload", "fail url=\(urlString) reason=empty")
                return
            }
            try? database.cacheImageData(data, for: urlString)
            log("FeedRefresh.ImagePreload", "success url=\(urlString) bytes=\(data.count)")
        } catch {
            log("FeedRefresh.ImagePreload", "fail url=\(urlString) error=\(error.localizedDescription)")
        }
    }
}
