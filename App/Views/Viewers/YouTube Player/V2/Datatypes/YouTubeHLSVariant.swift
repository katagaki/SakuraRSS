import Foundation

/// A single video variant entry parsed from an HLS master playlist.
nonisolated struct YouTubeHLSVariant: Sendable {
    let url: String
    let bandwidth: Int
    let resolution: String?
    let codecs: String?
    let audioGroup: String?
}
