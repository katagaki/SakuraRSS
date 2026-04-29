import Foundation

extension PodcastDownloadManager {

    func attemptTranscription(articleID: Int64, fileURL: URL, title: String) async {
        guard await PodcastTranscriber.isAvailable else {
            return
        }
        do {
            log("PodcastDownload", "Transcribing article \(articleID) located at \(fileURL.path())")
            let segments = try await PodcastTranscriber.transcribe(audioFileURL: fileURL, title: title)
            try DatabaseManager.shared.cacheTranscript(segments, for: articleID)
        } catch {
            print("Transcription failed for article \(articleID): \(error)")
        }
    }

    func markCompleted(articleID: Int64) {
        activeDownloads[articleID] = DownloadProgress(state: .completed, progress: 1.0)
        downloadTasks[articleID] = nil
        transcriptionTasks[articleID] = nil
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1))
            self?.activeDownloads[articleID] = nil
        }
    }

    func markFailed(articleID: Int64, error: String) {
        activeDownloads[articleID] = DownloadProgress(
            state: .failed,
            progress: 0,
            error: error
        )
        downloadTasks[articleID] = nil
        transcriptionTasks[articleID] = nil
    }
}
