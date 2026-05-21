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

    var isVideo: Bool { mimeType.hasPrefix("video/") }
    var isAudio: Bool { mimeType.hasPrefix("audio/") }
    var isMP4: Bool { mimeType.contains("mp4") }

    /// Whether this audio track is the video's original (undubbed) rendition.
    /// YouTube names the original track's `displayName` with an "original"
    /// suffix (e.g. "English (United States) original"), which is a more
    /// reliable signal than `audioIsDefault` for auto-dubbed videos where the
    /// default track follows the requesting locale rather than the source.
    var isOriginalAudioTrack: Bool {
        audioTrackDisplayName?.lowercased().contains("original") ?? false
    }

    var codecs: String? {
        guard let opening = mimeType.range(of: "codecs=\"") else { return nil }
        let remainder = mimeType[opening.upperBound...]
        guard let closing = remainder.firstIndex(of: "\"") else { return nil }
        return String(remainder[..<closing])
    }
}
