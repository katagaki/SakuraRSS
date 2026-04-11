import SwiftUI

struct PodcastSettingsView: View {

    @AppStorage("Podcast.PlaybackSpeed") private var playbackSpeed: Double = 1.0
    @AppStorage("Podcast.TranscriptionEngine") private var transcriptionEngine: String = TranscriptionEngineType.off.rawValue

    @State private var downloadsSize: Int64 = 0
    @State private var showDeleteDownloadsConfirmation = false
    @State private var showDeleteTranscriptsConfirmation = false
    @State private var showDeleteModelConfirmation = false
    @State private var isDownloadingModel = false
    @State private var modelDownloadError: String?
    @State private var modelReady = false

    private let playbackSpeedPresets: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]

    private var selectedEngine: TranscriptionEngineType {
        TranscriptionEngineType(rawValue: transcriptionEngine) ?? .off
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
                Picker("Podcast.Transcripts.Engine", selection: $transcriptionEngine) {
                    ForEach(TranscriptionEngineType.allCases) { engine in
                        Text(engine.displayName)
                            .tag(engine.rawValue)
                    }
                }
                if selectedEngine != .off {
                    Text(selectedEngine.engineDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // Model management for engines that require downloads
                if selectedEngine.requiresModelDownload {
                    if modelReady {
                        HStack {
                            Label("Podcast.Transcripts.Model.Ready", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Spacer()
                        }
                    } else if isDownloadingModel {
                        HStack {
                            Text("Podcast.Transcripts.Model.Downloading")
                            Spacer()
                            ProgressView()
                        }
                    } else {
                        Button {
                            downloadModel()
                        } label: {
                            Label("Podcast.Transcripts.Model.Download", systemImage: "arrow.down.circle")
                        }
                    }

                    if let error = modelDownloadError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Button(role: .destructive) {
                        showDeleteModelConfirmation = true
                    } label: {
                        Text("Podcast.Transcripts.Model.Delete")
                    }
                }

                Button(role: .destructive) {
                    showDeleteTranscriptsConfirmation = true
                } label: {
                    Text("Podcast.Transcripts.DeleteAll")
                }
            } header: {
                Text("Podcast.Transcripts.Title")
            }
        }
        .navigationTitle("Integrations.Podcast")
        .toolbarTitleDisplayMode(.inline)
        .task {
            downloadsSize = PodcastDownloadManager.totalDownloadedSize()
            refreshModelStatus()
        }
        .onChange(of: transcriptionEngine) { _, _ in
            modelDownloadError = nil
            refreshModelStatus()
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
        .alert(
            "Podcast.Transcripts.Model.Delete.ConfirmTitle",
            isPresented: $showDeleteModelConfirmation
        ) {
            Button("Podcast.Transcripts.Model.Delete.Confirm", role: .destructive) {
                deleteModel()
            }
            Button("Shared.Cancel", role: .cancel) { }
        } message: {
            Text("Podcast.Transcripts.Model.Delete.ConfirmMessage")
        }
    }

    // MARK: - Model Management

    private func refreshModelStatus() {
        guard let engine = PodcastTranscriber.engine(for: selectedEngine) else {
            modelReady = false
            return
        }
        modelReady = engine.isModelDownloaded
    }

    private func downloadModel() {
        guard let engine = PodcastTranscriber.engine(for: selectedEngine) else { return }
        isDownloadingModel = true
        modelDownloadError = nil
        Task {
            do {
                try await engine.downloadModel()
                await MainActor.run {
                    isDownloadingModel = false
                    refreshModelStatus()
                }
            } catch {
                await MainActor.run {
                    isDownloadingModel = false
                    modelDownloadError = error.localizedDescription
                }
            }
        }
    }

    private func deleteModel() {
        guard let engine = PodcastTranscriber.engine(for: selectedEngine) else { return }
        do {
            try engine.deleteModel()
        } catch {
            modelDownloadError = error.localizedDescription
        }
        refreshModelStatus()
    }

    private func formatSpeed(_ speed: Double) -> String {
        if speed == floor(speed) {
            return "\(Int(speed))×"
        }
        return "\(String(format: "%g", speed))×"
    }
}
