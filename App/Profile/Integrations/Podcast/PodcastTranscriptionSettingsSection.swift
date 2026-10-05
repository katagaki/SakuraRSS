#if !os(visionOS)

import SwiftUI
import Hanami

struct PodcastTranscriptionSettingsSection: View {

    @State private var setup = TranscriptionModelSetup()
    @State private var showDeleteTranscriptsConfirmation = false

    private var isEnabled: Binding<Bool> {
        Binding(get: { setup.isEnabled }, set: { setup.setEnabled($0) })
    }

    var body: some View {
        Section {
            Toggle(isOn: isEnabled) {
                Text(String(localized: "Transcripts.Engine.OnDevice", table: "Podcast"))
            }
            .disabled(setup.isDownloadingModel)

            if setup.isDownloadingModel {
                HStack {
                    Text(String(localized: "Transcripts.Model.Downloading", table: "Podcast"))
                    Spacer()
                    TranscriptionProgressDonut(progress: setup.downloadProgress)
                        .frame(width: 22, height: 22)
                }
            }

            if let downloadError = setup.downloadError {
                TranscriptionDownloadErrorText(error: downloadError)
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
                    setup.deleteAllTranscripts()
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
            setup.bootstrap()
        }
    }
}

struct TranscriptionDownloadErrorText: View {

    let error: TranscriptionModelSetup.DownloadError

    var body: some View {
        Text(error == .offline
             ? String(localized: "Transcripts.Download.OfflineError", table: "Podcast")
             : String(localized: "Transcripts.Download.GenericError", table: "Podcast"))
            .font(.footnote)
            .foregroundStyle(.red)
    }
}

struct TranscriptionProgressDonut: View {
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
