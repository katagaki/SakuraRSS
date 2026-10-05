#if !os(visionOS)

import Foundation
import Hanami
import Observation
import SwiftUI

/// Turning on-device transcription on downloads its model; turning it off,
/// or a failed download, removes it again. Shared by the iOS and Mac settings.
@MainActor
@Observable
final class TranscriptionModelSetup {

    enum DownloadError: Equatable {
        case offline
        case generic
    }

    private(set) var isEnabled = false
    private(set) var isDownloadingModel = false
    private(set) var downloadProgress: Double = 0
    private(set) var downloadError: DownloadError?

    @ObservationIgnored private let engine: any TranscriptionEngine = FluidTranscriberEngine()
    @ObservationIgnored private var downloadTask: Task<Void, Never>?
    @ObservationIgnored private var userCancelledDownload = false

    private var storedEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: PodcastTranscriber.enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: PodcastTranscriber.enabledKey) }
    }

    /// Reconciles the setting with the model on disk when settings open.
    func bootstrap() {
        if storedEnabled && !engine.isModelDownloaded {
            storedEnabled = false
        }
        isEnabled = storedEnabled
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        if enabled {
            downloadError = nil
            guard NetworkMonitor.shared.isOnline else {
                downloadError = .offline
                isEnabled = false
                return
            }
            storedEnabled = true
            startDownload()
        } else {
            // A failed download's error stays, explaining why the toggle went off.
            if downloadTask != nil {
                userCancelledDownload = true
                downloadTask?.cancel()
            }
            isDownloadingModel = false
            downloadProgress = 0
            storedEnabled = false
            try? engine.deleteModel()
        }
    }

    func deleteAllTranscripts() {
        let articleIDs = (try? DatabaseManager.shared.downloadedArticleIDs()) ?? []
        for articleID in articleIDs {
            try? DatabaseManager.shared.clearCachedTranscript(for: articleID)
        }
    }

    private func startDownload() {
        isDownloadingModel = true
        downloadProgress = 0
        downloadError = nil
        userCancelledDownload = false
        downloadTask = Task {
            do {
                try await engine.downloadModel(progress: { fraction in
                    Task { @MainActor [weak self] in
                        self?.downloadProgress = fraction
                    }
                })
                finishDownload(failed: false)
            } catch {
                finishDownload(failed: true)
            }
        }
    }

    private func finishDownload(failed: Bool) {
        downloadTask = nil
        isDownloadingModel = false
        downloadProgress = 0
        if userCancelledDownload {
            userCancelledDownload = false
            try? engine.deleteModel()
            return
        }
        guard failed else { return }
        downloadError = NetworkMonitor.shared.isOnline ? .generic : .offline
        storedEnabled = false
        isEnabled = false
        try? engine.deleteModel()
    }
}

#endif
