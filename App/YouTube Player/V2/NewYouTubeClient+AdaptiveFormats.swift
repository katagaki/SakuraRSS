import Foundation
import Hanami

extension NewYouTubeClient {

    static func parseAdaptiveFormats(_ entries: [[String: Any]]) -> [YouTubeAdaptiveFormat] {
        entries.compactMap(parseAdaptiveFormat)
    }

    /// Picks the highest-quality H.264/MP4 video track. AVPlayer's HLS fMP4
    /// support is reliable for AVC, so VP9/AV1 and WebM tracks are skipped.
    static func selectVideoFormat(
        from formats: [YouTubeAdaptiveFormat]
    ) -> YouTubeAdaptiveFormat? {
        let candidates = formats.filter {
            $0.isVideo && $0.isMP4 && ($0.codecs?.hasPrefix("avc1") ?? false)
        }
        let withinLimit = candidates.filter { ($0.height ?? 0) <= 1080 }
        let pool = withinLimit.isEmpty ? candidates : withinLimit
        return pool.max { lhs, rhs in
            if (lhs.height ?? 0) != (rhs.height ?? 0) {
                return (lhs.height ?? 0) < (rhs.height ?? 0)
            }
            return lhs.bitrate < rhs.bitrate
        }
    }

    /// Picks the highest-bitrate AAC/MP4 audio track, preferring the original
    /// audio track over dubbed alternatives.
    static func selectAudioFormat(
        from formats: [YouTubeAdaptiveFormat]
    ) -> YouTubeAdaptiveFormat? {
        let candidates = formats.filter { $0.isAudio && $0.isMP4 }
        let original = candidates.filter { $0.isDefaultAudioTrack != false }
        let pool = original.isEmpty ? candidates : original
        return pool.max { $0.bitrate < $1.bitrate }
    }

    private static func parseAdaptiveFormat(
        _ entry: [String: Any]
    ) -> YouTubeAdaptiveFormat? {
        guard
            let itag = entry["itag"] as? Int,
            let url = entry["url"] as? String,
            let mimeType = entry["mimeType"] as? String
        else { return nil }
        let audioTrack = entry["audioTrack"] as? [String: Any]
        return YouTubeAdaptiveFormat(
            itag: itag,
            url: url,
            mimeType: mimeType,
            bitrate: (entry["bitrate"] as? Int) ?? 0,
            width: entry["width"] as? Int,
            height: entry["height"] as? Int,
            approximateDurationMilliseconds: integer(entry["approxDurationMs"]),
            contentLength: integer(entry["contentLength"]),
            initRange: byteRange(entry["initRange"]),
            indexRange: byteRange(entry["indexRange"]),
            isDefaultAudioTrack: audioTrack?["audioIsDefault"] as? Bool
        )
    }

    private static func integer(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let string = value as? String { return Int(string) }
        return nil
    }

    private static func byteRange(_ value: Any?) -> YouTubeByteRange? {
        guard
            let dictionary = value as? [String: Any],
            let start = integer(dictionary["start"]),
            let end = integer(dictionary["end"])
        else { return nil }
        return YouTubeByteRange(start: start, end: end)
    }
}
