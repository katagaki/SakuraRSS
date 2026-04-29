import Foundation

extension FeedManager {

    /// Downloads and caches raw bytes for article images at utility priority.
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
            let (data, response) = try await URLSession.shared.data(for: .sakuraImage(url: url))
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
