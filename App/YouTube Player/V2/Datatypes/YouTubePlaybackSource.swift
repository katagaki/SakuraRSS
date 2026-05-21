import Foundation
import Hanami

/// How a video should be handed to `AVPlayer`. Live and legacy responses still
/// expose a ready-made HLS manifest; newer responses only expose adaptive
/// formats, which are repackaged into a locally served HLS stream.
nonisolated enum YouTubePlaybackSource: Sendable {
    case remoteHLS(URL)
    case localHLS(YouTubeLocalHLSStream)
}
