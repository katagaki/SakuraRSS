import Foundation

enum PodcastDownloadError: Error {
    case missingAudioURL
    case invalidAudioURL
    case storageUnavailable
    case downloadFailed(String)
}
