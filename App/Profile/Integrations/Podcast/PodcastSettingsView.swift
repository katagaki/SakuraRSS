import SwiftUI
import Hanami

struct PodcastSettingsView: View {

    @AppStorage("Podcast.PlaybackSpeed") private var playbackSpeed: Double = 1.0

    @State private var downloadsSize: Int64 = 0
    @State private var showDeleteDownloadsConfirmation = false

    private let playbackSpeedPresets: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]

    var body: some View {
        List {
            Section {
                Picker(String(localized: "PlaybackSpeed", table: "Podcast"), selection: $playbackSpeed) {
                    ForEach(playbackSpeedPresets, id: \.self) { preset in
                        Text(formatSpeed(preset))
                            .tag(preset)
                    }
                }
                .onChange(of: playbackSpeed) { _, newValue in
                    AudioPlayer.shared.setPlaybackRate(Float(newValue))
                }
            } header: {
                Text(String(localized: "Playback", table: "Podcast"))
            }

            Section {
                HStack {
                    Text(String(localized: "Downloads.StorageUsed", table: "Podcast"))
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: downloadsSize, countStyle: .file))
                        .foregroundStyle(.secondary)
                }
                Button(role: .destructive) {
                    showDeleteDownloadsConfirmation = true
                } label: {
                    Text(String(localized: "Downloads.DeleteAll", table: "Podcast"))
                }
                .disabled(downloadsSize == 0)
            } header: {
                Text(String(localized: "Downloads.Title", table: "Podcast"))
            }

            #if !os(visionOS)
            PodcastTranscriptionSettingsSection()
            #endif
        }
        .navigationTitle(String(localized: "Podcast", table: "Integrations"))
        .toolbarTitleDisplayMode(.inline)
        .sakuraBackground()
        .task {
            downloadsSize = PodcastDownloadManager.totalDownloadedSize()
        }
        .alert(
            String(localized: "Downloads.DeleteAll.ConfirmTitle", table: "Podcast"),
            isPresented: $showDeleteDownloadsConfirmation
        ) {
            Button(String(localized: "Downloads.DeleteAll.Confirm", table: "Podcast"), role: .destructive) {
                try? PodcastDownloadManager.shared.deleteAllDownloads()
                downloadsSize = PodcastDownloadManager.totalDownloadedSize()
            }
            Button("Shared.Cancel", role: .cancel) { }
        } message: {
            Text(String(localized: "Downloads.DeleteAll.ConfirmMessage", table: "Podcast"))
        }
    }

    private func formatSpeed(_ speed: Double) -> String {
        if speed == floor(speed) {
            return "\(Int(speed))×"
        }
        return "\(String(format: "%g", speed))×"
    }
}
