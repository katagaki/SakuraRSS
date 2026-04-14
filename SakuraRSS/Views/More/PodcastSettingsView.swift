import SwiftUI

struct PodcastSettingsView: View {

    @AppStorage("Podcast.PlaybackSpeed") private var playbackSpeed: Double = 1.0
    @AppStorage(PodcastTranscriber.enabledKey) private var transcriptionEnabled: Bool = false

    @State private var downloadsSize: Int64 = 0
    @State private var showDeleteDownloadsConfirmation = false
    @State private var showDeleteTranscriptsConfirmation = false

    @State private var toggleState: Bool = false
    @State private var hasBootstrapped = false
    @State private var isDownloadingModel = false
    @State private var downloadProgress: Double = 0
    @State private var modelReady = false
    @State private var downloadError: DownloadError?
    @State private var downloadTask: Task<Void, Never>?
    @State private var userCancelledDownload = false

    private let playbackSpeedPresets: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]

    private let engine: any TranscriptionEngine = FluidTranscriberEngine()

    private enum DownloadError: Equatable {
        case offline
        case generic
    }

    var body: some View {
        List {
            Section {
                Picker("Podcast.PlaybackSpeed", selection: $playbackSpeed) {
                    ForEach(playbackSpeedPresets, id: \.self) { preset in
                        Text(formatSpeed(preset))
                            .tag(preset)
                    }
                }
                .onChange(of: playbackSpeed) { _, newValue in
                    AudioPlayer.shared.setPlaybackRate(Float(newValue))
                }
            } header: {
                Text("Podcast.Playback")
            }

            Section {
                HStack {
                    Text("Podcast.Downloads.StorageUsed")
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: downloadsSize, countStyle: .file))
                        .foregroundStyle(.secondary)
                }
                Button(role: .destructive) {
                    showDeleteDownloadsConfirmation = true
                } label: {
                    Text("Podcast.Downloads.DeleteAll")
                }
                .disabled(downloadsSize == 0)
            } header: {
                Text("Podcast.Downloads.Title")
            }

            Section {
                Toggle(isOn: $toggleState) {
                    Text("Podcast.Transcripts.Engine.OnDevice")
                }
                .disabled(isDownloadingModel)
                .onChange(of: toggleState) { _, newValue in
                    // Ignore the synthetic change fired when `.task` syncs
                    // local state to persisted state on view appear.
                    guard hasBootstrapped else { return }
                    handleToggleChange(newValue)
                }

                if isDownloadingModel {
                    HStack {
                        Text("Podcast.Transcripts.Model.Downloading")
                        Spacer()
                        ProgressDonut(progress: downloadProgress)
                            .frame(width: 22, height: 22)
                    }
                }

                if let downloadError {
                    Text(downloadError == .offline
                         ? "Podcast.Transcripts.Download.OfflineError"
                         : "Podcast.Transcripts.Download.GenericError")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button(role: .destructive) {
                    showDeleteTranscriptsConfirmation = true
                } label: {
                    Text("Podcast.Transcripts.DeleteAll")
                }
            } header: {
                Text("Podcast.Transcripts.Title")
            } footer: {
                Text("Podcast.Transcripts.Engine.Footer")
            }
        }
        .navigationTitle("Integrations.Podcast")
        .toolbarTitleDisplayMode(.inline)
        .task {
            downloadsSize = PodcastDownloadManager.totalDownloadedSize()
            refreshModelStatus()
            // Reconcile the toggle with on-disk state: if the user flipped the
            // toggle on previously but the model never downloaded (or was
            // manually removed), reset the toggle to off so the UI matches
            // reality. Otherwise adopt the persisted value.
            if transcriptionEnabled && !modelReady {
                transcriptionEnabled = false
            }
            toggleState = transcriptionEnabled
            hasBootstrapped = true
        }
        .alert(
            "Podcast.Downloads.DeleteAll.ConfirmTitle",
            isPresented: $showDeleteDownloadsConfirmation
        ) {
            Button("Podcast.Downloads.DeleteAll.Confirm", role: .destructive) {
                try? PodcastDownloadManager.shared.deleteAllDownloads()
                downloadsSize = PodcastDownloadManager.totalDownloadedSize()
            }
            Button("Shared.Cancel", role: .cancel) { }
        } message: {
            Text("Podcast.Downloads.DeleteAll.ConfirmMessage")
        }
        .alert(
            "Podcast.Transcripts.DeleteAll.ConfirmTitle",
            isPresented: $showDeleteTranscriptsConfirmation
        ) {
            Button("Podcast.Transcripts.DeleteAll.Confirm", role: .destructive) {
                let ids = (try? DatabaseManager.shared.downloadedArticleIDs()) ?? []
                for id in ids {
                    try? DatabaseManager.shared.clearCachedTranscript(for: id)
                }
            }
            Button("Shared.Cancel", role: .cancel) { }
        } message: {
            Text("Podcast.Transcripts.DeleteAll.ConfirmMessage")
        }
    }

    // MARK: - Toggle handling

    private func handleToggleChange(_ newValue: Bool) {
        if newValue {
            // User flipped on. Any stale error goes away now.
            downloadError = nil
            // Guard: require network before kicking off a download.
            guard NetworkMonitor.shared.isOnline else {
                downloadError = .offline
                // Revert the toggle. The re-fire of this handler will land
                // in the else branch, which is idempotent.
                transcriptionEnabled = false
                toggleState = false
                return
            }
            transcriptionEnabled = true
            startDownload()
        } else {
            // Toggling off — cancel any in-flight download and wipe the model.
            // Don't clear downloadError here: if we're landing here because
            // the toggle was reverted after a failure, we want the error
            // message to stay visible.
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
                    // If the user toggled off after the download completed
                    // but before this continuation ran, delete the freshly
                    // downloaded model so the UI and disk stay in sync.
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
                    // User-initiated cancel: silently swallow, UI already reset.
                    if userCancelledDownload {
                        userCancelledDownload = false
                        try? engine.deleteModel()
                        refreshModelStatus()
                        return
                    }
                    // Distinguish offline from other failures so we can show
                    // the right message.
                    downloadError = NetworkMonitor.shared.isOnline ? .generic : .offline
                    // Roll the toggle back off and clean up any partial files.
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

    private func formatSpeed(_ speed: Double) -> String {
        if speed == floor(speed) {
            return "\(Int(speed))×"
        }
        return "\(String(format: "%g", speed))×"
    }
}

/// Circular determinate progress indicator styled as a donut.
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
