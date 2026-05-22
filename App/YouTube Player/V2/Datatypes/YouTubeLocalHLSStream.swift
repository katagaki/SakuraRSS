import Foundation
import Hanami

/// A self-contained set of HLS resources synthesized from `adaptiveFormats`.
/// Media playlists reference the original googlevideo URLs by byte range, so
/// only these small text manifests (and any subtitle WebVTT) are served
/// locally. Keyed by file name as requested over the custom scheme.
nonisolated struct YouTubeLocalHLSStream: Sendable {
    let resources: [String: Data]
    let resolution: String?
}

/// One selectable audio track in the synthesized master playlist.
nonisolated struct YouTubeLocalAudioRendition: Sendable {
    let format: YouTubeAdaptiveFormat
    let name: String
    let languageCode: String?
    let isDefault: Bool
    let playlistName: String
}

/// One selectable subtitle track, with its fetched WebVTT payload.
nonisolated struct YouTubeLocalSubtitleRendition: Sendable {
    let name: String
    let languageCode: String
    let vttName: String
    let playlistName: String
    let vtt: String
}
