import Foundation
import Observation

@Observable
@MainActor
public final class PodcastDownloadManager: NSObject, URLSessionDownloadDelegate {

    public static let shared = PodcastDownloadManager()

    public var activeDownloads: [Int64: DownloadProgress] = [:]

    /// Verified downloaded article IDs, kept in memory so row views don't
    /// query the database and filesystem on every render.
    public internal(set) var downloadedIDs: Set<Int64> = []

    public var urlSession: URLSession!
    public var downloadTasks: [Int64: URLSessionDownloadTask] = [:]
    public var taskArticleIDs: [Int: Int64] = [:]
    public var downloadContinuations: [Int64: CheckedContinuation<URL, any Error>] = [:]
    public let fileManager = FileManager.default

    public var transcriptionTasks: [Int64: Task<Void, Never>] = [:]

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
        Task { [weak self] in
            let ids = await Self.verifiedDownloadedIDs()
            self?.downloadedIDs = ids
        }
    }
}
