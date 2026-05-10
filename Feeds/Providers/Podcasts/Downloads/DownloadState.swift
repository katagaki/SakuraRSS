import Foundation

enum DownloadState: Sendable {
    case idle
    case downloading
    case transcribing
    case completed
    case failed
}
