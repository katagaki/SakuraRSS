import Foundation

public extension PodcastDownloadManager {

    func attemptTranscription(articleID: Int64, fileURL: URL, title: String) async {
        guard await PodcastTranscriber.isAvailable else {
            return
        }
        do {
            log("PodcastDownload", "Transcribing article \(articleID) located at \(fileURL.path())")
            let progressHandler: @Sendable (Double) -> Void = { [weak self] fraction in
                self?.reportTranscriptionProgress(articleID: articleID, fraction: fraction)
            }
            let segments = try await PodcastTranscriber.transcribe(
                audioFileURL: fileURL,
                title: title,
                progress: progressHandler
            )
            try DatabaseManager.shared.cacheTranscript(segments, for: articleID)
        } catch {
            log("PodcastDownload", "Transcription failed for article \(articleID): \(error)")
        }
    }

    nonisolated func reportTranscriptionProgress(articleID: Int64, fraction: Double) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            activeDownloads[articleID] = DownloadProgress(state: .transcribing, progress: fraction)
        }
    }

    func markCompleted(articleID: Int64) {
        log("PodcastDownload", "Download completed for article \(articleID)")
        activeDownloads[articleID] = DownloadProgress(state: .completed, progress: 1.0)
        downloadTasks[articleID] = nil
        transcriptionTasks[articleID] = nil
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1))
            self?.activeDownloads[articleID] = nil
        }
    }

    func markFailed(articleID: Int64, error: String) {
        log("PodcastDownload", "Download failed for article \(articleID): \(error)")
        activeDownloads[articleID] = DownloadProgress(
            state: .failed,
            progress: 0,
            error: error
        )
        downloadTasks[articleID] = nil
        transcriptionTasks[articleID] = nil
    }
}
