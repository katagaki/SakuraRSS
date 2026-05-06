import Foundation

struct DownloadProgress: Sendable {
    var state: DownloadState
    var progress: Double
    var error: String?
}
