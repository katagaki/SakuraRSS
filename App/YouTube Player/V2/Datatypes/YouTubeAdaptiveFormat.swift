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

    var isVideo: Bool { mimeType.hasPrefix("video/") }
    var isAudio: Bool { mimeType.hasPrefix("audio/") }
    var isMP4: Bool { mimeType.contains("mp4") }

    var codecs: String? {
        guard let opening = mimeType.range(of: "codecs=\"") else { return nil }
        let remainder = mimeType[opening.upperBound...]
        guard let closing = remainder.firstIndex(of: "\"") else { return nil }
        return String(remainder[..<closing])
    }
}
