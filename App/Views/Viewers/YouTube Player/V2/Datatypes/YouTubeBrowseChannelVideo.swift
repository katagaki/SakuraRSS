import Foundation

/// A video discovered through the InnerTube `browse` endpoint.
nonisolated struct YouTubeBrowseChannelVideo: Codable, Sendable {
    let url: String
    let thumbnailUrl: String
    let title: String
    let description: String
    let uploadDate: String
}
