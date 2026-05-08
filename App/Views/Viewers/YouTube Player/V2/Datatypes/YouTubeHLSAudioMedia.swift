import Foundation

/// An audio media entry parsed from an HLS master playlist.
nonisolated struct YouTubeHLSAudioMedia: Sendable {
    let url: String
    let groupId: String
    let name: String?
    let isDefault: Bool
}
