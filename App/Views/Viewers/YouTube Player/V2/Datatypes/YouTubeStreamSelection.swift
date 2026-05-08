import Foundation

/// Description of a single video stream variant resolved from the HLS master.
nonisolated struct YouTubeStreamSelection: Sendable {
    let videoVariantURL: URL
    let audioVariantURL: URL?
    let resolution: String?
    let bandwidth: Int
}
