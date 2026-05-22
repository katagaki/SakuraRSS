import Foundation
import Hanami

/// A byte range within a media file, as reported by an `adaptiveFormats` entry.
nonisolated struct YouTubeByteRange: Sendable {
    let start: Int
    let end: Int

    var length: Int { end - start + 1 }
}

/// A single adaptive (DASH) stream entry from the player response's
/// `streamingData.adaptiveFormats`. Each entry carries one elementary track,
/// so a playable stream needs a video entry and an audio entry combined.
nonisolated struct YouTubeAdaptiveFormat: Sendable {
    let itag: Int
    let url: String
    let mimeType: String
    let bitrate: Int
    let width: Int?
    let height: Int?
    let approximateDurationMilliseconds: Int?
    let contentLength: Int?
    let initRange: YouTubeByteRange?
    let indexRange: YouTubeByteRange?
    let isDefaultAudioTrack: Bool?
    let audioTrackDisplayName: String?
    let audioTrackId: String?
    let xtags: String?

    var isVideo: Bool { mimeType.hasPrefix("video/") }
    var isAudio: Bool { mimeType.hasPrefix("audio/") }
    var isMP4: Bool { mimeType.contains("mp4") }

    /// Language code carried in `audioTrack.id` (e.g. "en.4" -> "en").
    var audioLanguageCode: String? {
        audioTrackId?.split(separator: ".").first.map(String.init)
    }

    /// Source (undubbed) rendition. Uses the locale-independent `acont=original`
    /// marker in `xtags`; `displayName` is localized and `audioIsDefault`
    /// follows the requesting locale, both pointing at an auto-dub.
    var isOriginalAudioTrack: Bool {
        decodedXtags?.contains("original") ?? false
    }

    var isDRCAudioTrack: Bool {
        decodedXtags?.contains("drc") ?? false
    }

    private var decodedXtags: String? {
        guard let xtags else { return nil }
        var base64 = xtags
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        guard let data = Data(base64Encoded: base64) else { return nil }
        return String(data: data, encoding: .isoLatin1)
    }

    var codecs: String? {
        guard let opening = mimeType.range(of: "codecs=\"") else { return nil }
        let remainder = mimeType[opening.upperBound...]
        guard let closing = remainder.firstIndex(of: "\"") else { return nil }
        return String(remainder[..<closing])
    }
}
