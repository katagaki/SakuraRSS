import Foundation
import Hanami

extension NewYouTubeClient {

    /// Fetches title, uploader, upload date, and description for a single
    /// video by calling the InnerTube `player` endpoint with the web context.
    func fetchVideoMetadata(videoId: String) async throws -> YouTubeVideoMetadata {
        let body: [String: Any] = ["context": webContext(), "videoId": videoId]
        let data = try await post(endpoint: "player", body: body)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw YouTubeBrowseError.decodingFailed
        }
        let videoDetails = root["videoDetails"] as? [String: Any] ?? [:]
        let microformat = (root["microformat"] as? [String: Any])?["playerMicroformatRenderer"]
            as? [String: Any] ?? [:]

        let title = (videoDetails["title"] as? String)
            ?? Self.simpleText(microformat["title"]) ?? ""
        let uploader = (videoDetails["author"] as? String)
            ?? (microformat["ownerChannelName"] as? String) ?? ""
        let description = (videoDetails["shortDescription"] as? String)
            ?? Self.simpleText(microformat["description"]) ?? ""
        let publishDate = (microformat["publishDate"] as? String)
            ?? (microformat["uploadDate"] as? String)

        return YouTubeVideoMetadata(
            videoId: videoId,
            title: title,
            uploader: uploader,
            description: description,
            publishDateString: publishDate
        )
    }

    private static func simpleText(_ object: Any?) -> String? {
        guard let dictionary = object as? [String: Any] else { return nil }
        if let simple = dictionary["simpleText"] as? String { return simple }
        if let runs = dictionary["runs"] as? [[String: Any]] {
            return runs.compactMap { $0["text"] as? String }.joined()
        }
        return nil
    }
}
