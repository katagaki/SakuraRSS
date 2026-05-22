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
    let xtags: String?

    var isVideo: Bool { mimeType.hasPrefix("video/") }
    var isAudio: Bool { mimeType.hasPrefix("audio/") }
    var isMP4: Bool { mimeType.contains("mp4") }

    /// Whether this audio track is the video's original (undubbed) rendition.
    /// Derived from the `acont=original` marker in `xtags` rather than
    /// `displayName` or `audioIsDefault`: the display name is localized to the
    /// requesting locale (so an "original" suffix match fails on non-English
    /// devices) and `audioIsDefault` follows that locale, pointing at an
    /// auto-dub. `xtags` carries `acont=original` for the source track and
    /// `acont=dubbed` for auto-dubs regardless of locale.
    var isOriginalAudioTrack: Bool {
        decodedXtags?.contains("original") ?? false
    }

    /// Whether this is a loudness-normalized (dynamic range compressed) variant.
    /// These are duplicates of a track marked with `drc` in `xtags` and should
    /// not be preferred over the unprocessed rendition.
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
