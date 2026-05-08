import Foundation

/// Errors raised by the InnerTube-based YouTube browse client.
nonisolated enum YouTubeBrowseError: Error, Sendable {
    case invalidURL
    case compressionFailed
    case decodingFailed
    case missingData
    case unexpectedResponse(status: Int)
}
