import Hanami
import SwiftUI

/// iOS's Podcast settings: downloaded episodes, and on-device transcription,
/// which transcribes episodes as they download.
struct PodcastIntegrationSettings: View {

    @State private var setup = TranscriptionModelSetup()
    @State private var downloadsSize: Int64 = 0
    @State private var isConfirmingDeleteDownloads = false
    @State private var isConfirmingDeleteTranscripts = false

    private var isTranscriptionEnabled: Binding<Bool> {
        Binding(get: { setup.isEnabled }, set: { setup.setEnabled($0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Downloads.Title", table: "Podcast"))
                .font(.headline)
            LabeledContent(String(localized: "Downloads.StorageUsed", table: "Podcast")) {
                Text(ByteCountFormatter.string(fromByteCount: downloadsSize, countStyle: .file))
                    .foregroundStyle(.secondary)
            }
            Button(String(localized: "Downloads.DeleteAll", table: "Podcast") + "…") {
                isConfirmingDeleteDownloads = true
            }
            .disabled(downloadsSize == 0)

            Text(String(localized: "Transcripts.Title", table: "Podcast"))
                .font(.headline)
                .padding(.top, 12)
            Toggle(String(localized: "Transcripts.Engine.OnDevice", table: "Podcast"), isOn: isTranscriptionEnabled)
                .disabled(setup.isDownloadingModel)
            if setup.isDownloadingModel {
                HStack(spacing: 8) {
                    TranscriptionProgressDonut(progress: setup.downloadProgress)
                        .frame(width: 16, height: 16)
                    Text(String(localized: "Transcripts.Model.Downloading", table: "Podcast"))
                        .foregroundStyle(.secondary)
                }
            }
            if let downloadError = setup.downloadError {
                TranscriptionDownloadErrorText(error: downloadError)
            }
            SettingsNote(text: String(localized: "Transcripts.Engine.Footer", table: "Podcast"))
            Button(String(localized: "Transcripts.DeleteAll", table: "Podcast") + "…") {
                isConfirmingDeleteTranscripts = true
            }
        }
        .task {
            setup.bootstrap()
            downloadsSize = PodcastDownloadManager.totalDownloadedSize()
        }
        .confirmationDialog(
            String(localized: "Downloads.DeleteAll.ConfirmTitle", table: "Podcast"),
            isPresented: $isConfirmingDeleteDownloads
        ) {
            Button(String(localized: "Downloads.DeleteAll.Confirm", table: "Podcast"), role: .destructive) {
                try? PodcastDownloadManager.shared.deleteAllDownloads()
                downloadsSize = PodcastDownloadManager.totalDownloadedSize()
            }
        } message: {
            Text(String(localized: "Downloads.DeleteAll.ConfirmMessage", table: "Podcast"))
        }
        .confirmationDialog(
            String(localized: "Transcripts.DeleteAll.ConfirmTitle", table: "Podcast"),
            isPresented: $isConfirmingDeleteTranscripts
        ) {
            Button(String(localized: "Transcripts.DeleteAll.Confirm", table: "Podcast"), role: .destructive) {
                setup.deleteAllTranscripts()
            }
        } message: {
            Text(String(localized: "Transcripts.DeleteAll.ConfirmMessage", table: "Podcast"))
        }
    }
}
