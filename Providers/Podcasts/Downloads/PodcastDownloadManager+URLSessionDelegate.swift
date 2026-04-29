import Foundation

extension PodcastDownloadManager {

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let taskID = downloadTask.taskIdentifier
        Task { @MainActor [weak self] in
            guard let self,
                  let articleID = taskArticleIDs[taskID] else { return }
            let fraction: Double
            if totalBytesExpectedToWrite > 0 {
                fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            } else {
                fraction = 0
            }
            activeDownloads[articleID] = DownloadProgress(
                state: .downloading,
                progress: fraction
            )
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Copy before the system deletes `location`.
        let tempCopy = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.moveItem(at: location, to: tempCopy)

        let taskID = downloadTask.taskIdentifier
        Task { @MainActor [weak self] in
            guard let self,
                  let articleID = taskArticleIDs[taskID],
                  let continuation = downloadContinuations.removeValue(forKey: articleID) else {
                return
            }
            taskArticleIDs[taskID] = nil
            continuation.resume(returning: tempCopy)
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        guard let error else { return }
        let taskID = task.taskIdentifier
        Task { @MainActor [weak self] in
            guard let self,
                  let articleID = taskArticleIDs.removeValue(forKey: taskID),
                  let continuation = downloadContinuations.removeValue(forKey: articleID) else {
                return
            }
            continuation.resume(throwing: error)
        }
    }
}
