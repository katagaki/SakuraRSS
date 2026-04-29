import Foundation

extension PodcastDownloadManager {

    func downloadEpisode(article: Article) {
        guard activeDownloads[article.id] == nil else { return }
        guard let audioURLString = article.audioURL,
              let audioURL = URL(string: audioURLString) else {
            activeDownloads[article.id] = DownloadProgress(
                state: .failed,
                progress: 0,
                error: "Missing audio URL"
            )
            return
        }

        activeDownloads[article.id] = DownloadProgress(state: .downloading, progress: 0)

        let task = Task { @MainActor [weak self] in
            do {
                try await self?.performDownload(article: article, audioURL: audioURL)
            } catch is CancellationError {
                // cancelDownload() already cleaned up state.
            } catch let urlError as URLError where urlError.code == .cancelled {
                // Same as above.
            } catch {
                self?.markFailed(articleID: article.id, error: error.localizedDescription)
            }
        }
        transcriptionTasks[article.id] = task
    }

    func performDownload(article: Article, audioURL: URL) async throws {
        guard let episodeDir = episodeDirectory(for: article.id) else {
            throw PodcastDownloadError.storageUnavailable
        }
        let name = filename(from: audioURL)
        let destination = episodeDir.appendingPathComponent(name)
        let articleID = article.id

        let dir = episodeDir
        let dest = destination
        try await Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: dir.path) {
                try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            if fileManager.fileExists(atPath: dest.path) {
                try? fileManager.removeItem(at: dest)
            }
        }.value

        let tempURL: URL = try await withCheckedThrowingContinuation { continuation in
            let sessionTask = urlSession.downloadTask(with: audioURL)
            downloadTasks[articleID] = sessionTask
            taskArticleIDs[sessionTask.taskIdentifier] = articleID
            downloadContinuations[articleID] = continuation
            sessionTask.resume()
        }

        downloadTasks[articleID] = nil

        try await Task.detached(priority: .utility) {
            try FileManager.default.moveItem(at: tempURL, to: dest)
        }.value

        // Store relative path so it survives container path changes.
        let relativePath = "\(articleID)/\(name)"
        try DatabaseManager.shared.setDownloadPath(relativePath, for: articleID)

        // Transcription failure is non-fatal; we still markCompleted below.
        if await PodcastTranscriber.isAvailable {
            activeDownloads[articleID] = DownloadProgress(state: .transcribing, progress: 0)
            let title = article.title
            await attemptTranscription(articleID: articleID, fileURL: destination, title: title)
        }

        markCompleted(articleID: articleID)
    }
}
