import Foundation
import Hanami

/// A self-contained set of HLS playlists synthesized from `adaptiveFormats`.
/// The media playlists reference the original googlevideo URLs by byte range,
/// so only these small text manifests need to be served locally.
nonisolated struct YouTubeLocalHLSStream: Sendable {
    let masterPlaylist: String
    let videoPlaylist: String
    let audioPlaylist: String
    let resolution: String?
    let userAgent: String
}
