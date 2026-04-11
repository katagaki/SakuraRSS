import SwiftUI

struct PodcastDownloadButton: View {

    let article: Article
    let size: CGFloat
    let lineWidth: CGFloat

    private let downloadManager = PodcastDownloadManager.shared
    private let networkMonitor = NetworkMonitor.shared

    @State private var showingDeleteAlert = false

    private var downloadProgress: DownloadProgress? {
        downloadManager.activeDownloads[article.id]
    }

    private var isDownloaded: Bool {
        downloadManager.isDownloaded(articleID: article.id)
    }

    private var isOffline: Bool {
        !networkMonitor.isOnline
    }

    private var canDownload: Bool {
        !isDownloaded && !isOffline && downloadProgress == nil
    }

    init(article: Article, size: CGFloat = 28, lineWidth: CGFloat = 3) {
        self.article = article
        self.size = size
        self.lineWidth = lineWidth
    }

    var body: some View {
        Group {
            if let progress = downloadProgress {
                Button {
                    downloadManager.cancelDownload(articleID: article.id)
                } label: {
                    donutProgress(progress: progress.progress)
                }
                .buttonStyle(.plain)
            } else if isDownloaded {
                Button {
                    showingDeleteAlert = true
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: size))
                        .foregroundStyle(.accent)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .alert("Podcast.DeleteDownload", isPresented: $showingDeleteAlert) {
                    Button("Shared.Cancel", role: .cancel) { }
                    Button("Podcast.DeleteDownload.Confirm", role: .destructive) {
                        try? downloadManager.deleteDownload(articleID: article.id)
                    }
                } message: {
                    Text("Podcast.DeleteDownload.Message")
                }
            } else {
                Button {
                    downloadManager.downloadEpisode(article: article)
                } label: {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: size))
                        .foregroundStyle(canDownload ? .accent : .secondary)
                        .symbolRenderingMode(.multicolor)
                }
                .buttonStyle(.plain)
                .disabled(!canDownload)
            }
        }
        .frame(width: size, height: size)
    }

    private func donutProgress(progress: Double) -> some View {
        ZStack {
            // Background track
            Circle()
                .stroke(.secondary.opacity(0.2), lineWidth: lineWidth)
                .frame(width: size - lineWidth, height: size - lineWidth)

            // Progress arc
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: size - lineWidth, height: size - lineWidth)
                .rotationEffect(.degrees(-90))
                .animation(.smooth, value: progress)

            // Stop icon in center
            Image(systemName: "stop.fill")
                .font(.system(size: size * 0.3))
                .foregroundStyle(.accent)
        }
    }
}
