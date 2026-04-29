import Foundation

enum DownloadState: Sendable {
    case idle
    case downloading
    case transcribing
    case completed
    case failed
}

struct DownloadProgress: Sendable {
    var state: DownloadState
    var progress: Double
    var error: String?
}

enum PodcastDownloadError: Error {
    case missingAudioURL
    case invalidAudioURL
    case storageUnavailable
    case downloadFailed(String)
}
