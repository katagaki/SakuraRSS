import Foundation

public extension XProvider {

    static func parseTweetVideo(from legacy: [String: Any]) -> (url: String, aspectRatio: Double)? {
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

        let best = variants
            .filter { ($0["content_type"] as? String) == "video/mp4" }
            .max { (($0["bitrate"] as? Int) ?? 0) < (($1["bitrate"] as? Int) ?? 0) }
        guard let urlString = best?["url"] as? String else { return nil }

        var aspectRatio = 16.0 / 9.0
        if let ratio = videoInfo["aspect_ratio"] as? [Int], ratio.count == 2, ratio[1] != 0 {
            aspectRatio = Double(ratio[0]) / Double(ratio[1])
        }
        return (urlString, aspectRatio)
    }
}
