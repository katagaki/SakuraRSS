import Foundation
import Hanami

/// A self-contained set of HLS resources synthesized from `adaptiveFormats`.
/// Playlists are served from `resources`; media byte ranges are proxied from
/// `mediaSources` (fetched from googlevideo with the iOS User-Agent) because
/// AVPlayer's own requests are rejected for far-range seeks.
nonisolated struct YouTubeLocalHLSStream: Sendable {
    let resources: [String: Data]
    let mediaSources: [String: YouTubeLocalMediaSource]
    let resolution: String?
    let userAgent: String
}

/// The remote media file a synthesized media playlist's byte ranges point at.
nonisolated struct YouTubeLocalMediaSource: Sendable {
    let url: String
    let contentLength: Int
    let mimeType: String
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
