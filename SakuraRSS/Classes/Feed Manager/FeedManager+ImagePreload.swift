import Foundation

/// Accumulates article image URLs discovered during a refresh pass so
/// `refreshAllFeeds` can run a single bounded-concurrency preload step
/// at the end instead of contending with the feed-body fetches.
actor ImagePreloadCollector {

    private var urls: [String] = []

    func add(_ newURLs: [String]) {
        urls.append(contentsOf: newURLs)
    }

    func drain() -> [String] {
        let out = urls
        urls.removeAll(keepingCapacity: false)
        return out
    }
}

extension FeedManager {

    /// Downloads and SQLite-caches the raw bytes for the given article
    /// image URLs.  Runs at `.utility` priority with a small concurrency
    /// cap so foreground scroll-driven image requests and the main
    /// refresh pipeline stay ahead of this work.  Only the encoded bytes
    /// are persisted — the `CachedAsyncImage` loader still does the
    /// ImageIO downsample on first display, so this step adds zero
    /// decoded-pixel memory pressure.
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
                for await _ in group {
                    if Task.isCancelled {
                        group.cancelAll()
                    }
                }
            }
        }
    }

    nonisolated private static func downloadAndCacheImage(url: URL) async {
        let urlString = url.absoluteString
        let database = DatabaseManager.shared
        if database.isImageCached(for: urlString) { return }
        do {
            let (data, response) = try await URLSession.shared.data(for: .sakura(url: url))
            if let http = response as? HTTPURLResponse,
               !(200..<300).contains(http.statusCode) {
                return
            }
            guard !data.isEmpty else { return }
            try? database.cacheImageData(data, for: urlString)
        } catch {
            return
        }
    }
}
