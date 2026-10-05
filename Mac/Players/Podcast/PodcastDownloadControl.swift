import Hanami
import SwiftUI

/// Downloading an episode as standard buttons: Download, its progress with a
/// way to stop it, or Downloaded, which offers to remove the copy.
struct PodcastDownloadControl: View {

    let article: Article
    private let downloadManager = PodcastDownloadManager.shared
    private let networkMonitor = NetworkMonitor.shared
    @State private var isConfirmingDelete = false

    var body: some View {
        if let progress = downloadManager.activeDownloads[article.id], progress.state != .completed {
            HStack(spacing: 8) {
                ProgressView(value: progress.progress)
                    .frame(width: 100)
                Button(String(localized: "Shared.Cancel")) {
                    downloadManager.cancelDownload(articleID: article.id)
                }
            }
        } else if downloadManager.isDownloaded(articleID: article.id) {
            Button(String(localized: "Downloaded", table: "Podcast"), systemImage: "checkmark.circle") {
                isConfirmingDelete = true
            }
            .confirmationDialog(
                String(localized: "DeleteDownload", table: "Podcast"),
                isPresented: $isConfirmingDelete
            ) {
                Button(String(localized: "DeleteDownload.Confirm", table: "Podcast"), role: .destructive) {
                    try? downloadManager.deleteDownload(articleID: article.id)
                }
            } message: {
                Text(String(localized: "DeleteDownload.Message", table: "Podcast"))
            }
        } else {
            Button(String(localized: "Download", table: "Podcast"), systemImage: "arrow.down.circle") {
                downloadManager.downloadEpisode(article: article)
            }
            .disabled(!networkMonitor.isOnline)
        }
    }
}
