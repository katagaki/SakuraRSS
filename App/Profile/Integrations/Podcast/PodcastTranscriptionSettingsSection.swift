#if !os(visionOS)

import SwiftUI
import Hanami

struct PodcastTranscriptionSettingsSection: View {

    @AppStorage(PodcastTranscriber.enabledKey) private var transcriptionEnabled: Bool = false

    @State private var showDeleteTranscriptsConfirmation = false
    @State private var toggleState: Bool = false
    @State private var hasBootstrapped = false
    @State private var isDownloadingModel = false
    @State private var downloadProgress: Double = 0
    @State private var modelReady = false
    @State private var downloadError: DownloadError?
    @State private var downloadTask: Task<Void, Never>?
    @State private var userCancelledDownload = false

    private let engine: any TranscriptionEngine = FluidTranscriberEngine()

    private enum DownloadError: Equatable {
        case offline
        case generic
    }

    var body: some View {
        Section {
            Toggle(isOn: $toggleState) {
                Text(String(localized: "Transcripts.Engine.OnDevice", table: "Podcast"))
            }
            .disabled(isDownloadingModel)
            .onChange(of: toggleState) { _, newValue in
                // Ignore synthetic change fired when `.task` syncs on appear.
                guard hasBootstrapped else { return }
                handleToggleChange(newValue)
            }

            if isDownloadingModel {
                HStack {
                    Text(String(localized: "Transcripts.Model.Downloading", table: "Podcast"))
                    Spacer()
                    ProgressDonut(progress: downloadProgress)
                        .frame(width: 22, height: 22)
                }
            }

            if let downloadError {
                Text(downloadError == .offline
                     ? String(localized: "Transcripts.Download.OfflineError", table: "Podcast")
                     : String(localized: "Transcripts.Download.GenericError", table: "Podcast"))
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button(role: .destructive) {
                showDeleteTranscriptsConfirmation = true
            } label: {
                Text(String(localized: "Transcripts.DeleteAll", table: "Podcast"))
            }
            .alert(
                String(localized: "Transcripts.DeleteAll.ConfirmTitle", table: "Podcast"),
                isPresented: $showDeleteTranscriptsConfirmation
            ) {
                Button(String(localized: "Transcripts.DeleteAll.Confirm", table: "Podcast"), role: .destructive) {
                    let articleIDs = (try? DatabaseManager.shared.downloadedArticleIDs()) ?? []
                    for articleID in articleIDs {
                        try? DatabaseManager.shared.clearCachedTranscript(for: articleID)
                    }
                }
                Button("Shared.Cancel", role: .cancel) { }
            } message: {
                Text(String(localized: "Transcripts.DeleteAll.ConfirmMessage", table: "Podcast"))
            }
        } header: {
            Text(String(localized: "Transcripts.Title", table: "Podcast"))
        } footer: {
            Text(String(localized: "Transcripts.Engine.Footer", table: "Podcast"))
        }
        .task {
            refreshModelStatus()
            // Reconcile toggle with on-disk state when the model is missing.
            if transcriptionEnabled && !modelReady {
                transcriptionEnabled = false
            }
            toggleState = transcriptionEnabled
            hasBootstrapped = true
        }
    }

    // MARK: - Toggle handling

    private func handleToggleChange(_ newValue: Bool) {
        if newValue {
            downloadError = nil
            guard NetworkMonitor.shared.isOnline else {
                downloadError = .offline
                transcriptionEnabled = false
                toggleState = false
                return
            }
            transcriptionEnabled = true
            startDownload()
        } else {
            // Don't clear downloadError: preserve it when toggle reverted after a failure.
            if downloadTask != nil {
                userCancelledDownload = true
                downloadTask?.cancel()
            }
            isDownloadingModel = false
            downloadProgress = 0
            transcriptionEnabled = false
            try? engine.deleteModel()
            refreshModelStatus()
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
                    Task { @MainActor in
                        downloadProgress = fraction
                    }
                })
                await MainActor.run {
                    downloadTask = nil
                    if userCancelledDownload {
                        userCancelledDownload = false
                        try? engine.deleteModel()
                        isDownloadingModel = false
                        downloadProgress = 0
                        refreshModelStatus()
                        return
                    }
                    isDownloadingModel = false
                    downloadProgress = 0
                    refreshModelStatus()
                }
            } catch {
                await MainActor.run {
                    downloadTask = nil
                    isDownloadingModel = false
                    downloadProgress = 0
                    if userCancelledDownload {
                        userCancelledDownload = false
                        try? engine.deleteModel()
                        refreshModelStatus()
                        return
                    }
                    downloadError = NetworkMonitor.shared.isOnline ? .generic : .offline
                    transcriptionEnabled = false
                    try? engine.deleteModel()
                    toggleState = false
                    refreshModelStatus()
                }
            }
        }
    }

    private func refreshModelStatus() {
        modelReady = engine.isModelDownloaded
    }
}

private struct ProgressDonut: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.25), lineWidth: 3)
            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(1, progress))))
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.15), value: progress)
        }
    }
}

#endif
