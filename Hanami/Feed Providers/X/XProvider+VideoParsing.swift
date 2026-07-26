import Foundation

public extension XProvider {

    struct ParsedTweetVideo: Sendable {
        public let url: String
        public let aspectRatio: Double
        public let thumbnailURL: String?
        public let isGIF: Bool
    }

    static func parseTweetVideo(from legacy: [String: Any]) -> ParsedTweetVideo? {
        let extendedEntities = legacy["extended_entities"] as? [String: Any]
        let media = extendedEntities?["media"] as? [[String: Any]]
        guard let videoMedia = media?.first(where: {
            let type = $0["type"] as? String
            return type == "video" || type == "animated_gif"
        }),
            let videoInfo = videoMedia["video_info"] as? [String: Any],
            let variants = videoInfo["variants"] as? [[String: Any]] else {
            return nil
        }

        let isGIF = (videoMedia["type"] as? String) == "animated_gif"

        // Prefer the adaptive HLS stream (what X's own clients play) so
        // AVPlayer picks a rendition for the connection instead of the
        // top progressive MP4, which can be a 25 Mbps 4K file. GIFs only
        // ever have a single small MP4 variant.
        let hls = variants.first {
            ($0["content_type"] as? String) == "application/x-mpegURL"
        }
        let bestMP4 = variants
            .filter { ($0["content_type"] as? String) == "video/mp4" }
            .max { (($0["bitrate"] as? Int) ?? 0) < (($1["bitrate"] as? Int) ?? 0) }
        let best = isGIF ? bestMP4 : (hls ?? bestMP4)
        guard let urlString = best?["url"] as? String else { return nil }

        var aspectRatio = 16.0 / 9.0
        if let ratio = videoInfo["aspect_ratio"] as? [Int], ratio.count == 2, ratio[1] != 0 {
            aspectRatio = Double(ratio[0]) / Double(ratio[1])
        }
        return ParsedTweetVideo(
            url: urlString,
            aspectRatio: aspectRatio,
            thumbnailURL: videoMedia["media_url_https"] as? String,
            isGIF: isGIF
        )
    }
}
