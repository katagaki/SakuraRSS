import Foundation

/// Errors raised by the InnerTube-based YouTube browse client.
nonisolated enum YouTubeBrowseError: Error, Sendable {
    case invalidURL
    case compressionFailed
    case decodingFailed
    case missingData
    case unexpectedResponse(status: Int)
}

/// A video discovered through the InnerTube `browse` endpoint.
nonisolated struct YouTubeBrowseChannelVideo: Codable, Sendable {
    let url: String
    let thumbnailUrl: String
    let title: String
    let description: String
    let uploadDate: String
}

/// Description of a single video stream variant resolved from the HLS master.
nonisolated struct YouTubeStreamSelection: Sendable {
    let videoVariantURL: URL
    let audioVariantURL: URL?
    let resolution: String?
    let bandwidth: Int
}
