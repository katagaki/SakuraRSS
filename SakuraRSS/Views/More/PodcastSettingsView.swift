import SwiftUI

struct PodcastSettingsView: View {

    @AppStorage("Podcast.PlaybackSpeed") private var playbackSpeed: Double = 1.0

    @State private var downloadsSize: Int64 = 0
    @State private var showDeleteDownloadsConfirmation = false
    @State private var showDeleteTranscriptsConfirmation = false

    private let playbackSpeedPresets: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]

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

    private func formatSpeed(_ speed: Double) -> String {
        if speed == floor(speed) {
            return "\(Int(speed))×"
        }
        return "\(String(format: "%g", speed))×"
    }
}
