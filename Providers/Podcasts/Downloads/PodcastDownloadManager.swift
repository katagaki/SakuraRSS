import Foundation
import Observation

@Observable
@MainActor
final class PodcastDownloadManager: NSObject, URLSessionDownloadDelegate {

    static let shared = PodcastDownloadManager()

    var activeDownloads: [Int64: DownloadProgress] = [:]

    var urlSession: URLSession!
    var downloadTasks: [Int64: URLSessionDownloadTask] = [:]
    var taskArticleIDs: [Int: Int64] = [:]
    var downloadContinuations: [Int64: CheckedContinuation<URL, any Error>] = [:]
    let fileManager = FileManager.default

    var transcriptionTasks: [Int64: Task<Void, Never>] = [:]

    private override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 3600
        config.httpAdditionalHeaders = ["User-Agent": sakuraUserAgent]
        self.urlSession = URLSession(
            configuration: config,
            delegate: self,
            delegateQueue: nil
        )
    }
}
