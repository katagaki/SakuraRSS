import Foundation

/// Discovers public videos for a YouTube channel handle by walking the
/// InnerTube `browse` response.
nonisolated struct YouTubeBrowseChannelProvider: Sendable {

    let inner: YouTubeInnerTube

    static func bootstrap(session: URLSession = .shared) async -> YouTubeBrowseChannelProvider {
        YouTubeBrowseChannelProvider(inner: await YouTubeInnerTube.bootstrap(session: session))
    }

    func fetchVideos(handle: String) async throws -> [YouTubeBrowseChannelVideo] {
        let normalized = handle.hasPrefix("@") ? handle : "@\(handle)"
        let resolveURL = "\(YouTubeInnerTube.host)/\(normalized)/videos"

        let resolveData = try await inner.post(
            endpoint: "navigation/resolve_url",
            body: ["context": inner.webContext(), "url": resolveURL]
        )
        guard
            let resolveJSON = try JSONSerialization.jsonObject(with: resolveData) as? [String: Any],
            let endpoint = resolveJSON["endpoint"] as? [String: Any],
            let browse = endpoint["browseEndpoint"] as? [String: Any],
            let browseId = browse["browseId"] as? String
        else { throw YouTubeBrowseError.missingData }

        var browseRequest: [String: Any] = [
            "context": inner.webContext(),
            "browseId": browseId
        ]
        if let params = browse["params"] as? String { browseRequest["params"] = params }
        let browseData = try await inner.post(endpoint: "browse", body: browseRequest)

        let parsed = try Self.extractVideos(from: browseData)
        return await enrichWithDates(parsed)
    }

    private static func extractVideos(from data: Data) throws -> [YouTubeBrowseChannelVideo] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw YouTubeBrowseError.decodingFailed
        }
        return collectVideoRenderers(root).compactMap(parseVideoRenderer)
    }

    private static func collectVideoRenderers(_ object: Any) -> [[String: Any]] {
        var output: [[String: Any]] = []
        if let dictionary = object as? [String: Any] {
            if let renderer = dictionary["videoRenderer"] as? [String: Any] {
                output.append(renderer)
                for (key, value) in dictionary where key != "videoRenderer" {
                    output.append(contentsOf: collectVideoRenderers(value))
                }
            } else {
                for (_, value) in dictionary {
                    output.append(contentsOf: collectVideoRenderers(value))
                }
            }
        } else if let array = object as? [Any] {
            for element in array {
                output.append(contentsOf: collectVideoRenderers(element))
            }
        }
        return output
    }

    private static func parseVideoRenderer(
        _ renderer: [String: Any]
    ) -> YouTubeBrowseChannelVideo? {
        guard let videoId = renderer["videoId"] as? String else { return nil }
        let thumbnails = (renderer["thumbnail"] as? [String: Any])?["thumbnails"]
            as? [[String: Any]] ?? []
        let bestThumbnail = thumbnails.last?["url"] as? String ?? ""
        return YouTubeBrowseChannelVideo(
            url: "https://www.youtube.com/watch?v=\(videoId)",
            thumbnailUrl: bestThumbnail,
            title: textFromRuns(renderer["title"]),
            description: textFromRuns(renderer["descriptionSnippet"]),
            uploadDate: textFromRuns(renderer["publishedTimeText"])
        )
    }

    private static func textFromRuns(_ object: Any?) -> String {
        guard let dictionary = object as? [String: Any] else { return "" }
        if let simple = dictionary["simpleText"] as? String { return simple }
        if let runs = dictionary["runs"] as? [[String: Any]] {
            return runs.compactMap { $0["text"] as? String }.joined()
        }
        return ""
    }

    private func enrichWithDates(
        _ videos: [YouTubeBrowseChannelVideo]
    ) async -> [YouTubeBrowseChannelVideo] {
        await withTaskGroup(
            of: (Int, String?).self,
            returning: [YouTubeBrowseChannelVideo].self
        ) { group in
            for (index, video) in videos.enumerated() {
                guard let videoId = Self.videoId(from: video.url) else { continue }
                group.addTask {
                    let date = try? await self.fetchPublishDate(videoId: videoId)
                    return (index, date)
                }
            }
            var dates: [Int: String] = [:]
            for await (index, date) in group {
                if let date { dates[index] = date }
            }
            return videos.enumerated().map { (index, video) in
                guard let date = dates[index] else { return video }
                return YouTubeBrowseChannelVideo(
                    url: video.url,
                    thumbnailUrl: video.thumbnailUrl,
                    title: video.title,
                    description: video.description,
                    uploadDate: date
                )
            }
        }
    }

    private func fetchPublishDate(videoId: String) async throws -> String? {
        let body: [String: Any] = ["context": inner.webContext(), "videoId": videoId]
        let data = try await inner.post(endpoint: "player", body: body)
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let microformat = root["microformat"] as? [String: Any],
            let renderer = microformat["playerMicroformatRenderer"] as? [String: Any]
        else { return nil }
        return renderer["publishDate"] as? String ?? renderer["uploadDate"] as? String
    }

    private static func videoId(from watchURL: String) -> String? {
        guard let components = URLComponents(string: watchURL) else { return nil }
        return components.queryItems?.first(where: { $0.name == "v" })?.value
    }
}
