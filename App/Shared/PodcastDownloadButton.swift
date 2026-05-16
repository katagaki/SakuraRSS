import SwiftUI
import Hanami

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
                    if progress.state == .transcribing {
                        transcribingDonut(progress: progress.progress)
                    } else {
                        donutProgress(progress: progress.progress)
                    }
                }
                .buttonStyle(.plain)
            } else if isDownloaded {
                Button {
                    showingDeleteAlert = true
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: size))
                        .foregroundStyle(Color.platformAccent)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .alert(String(localized: "DeleteDownload", table: "Podcast"), isPresented: $showingDeleteAlert) {
                    Button("Shared.Cancel", role: .cancel) { }
                    Button(String(localized: "DeleteDownload.Confirm", table: "Podcast"), role: .destructive) {
                        try? downloadManager.deleteDownload(articleID: article.id)
                    }
                } message: {
                    Text(String(localized: "DeleteDownload.Message", table: "Podcast"))
                }
            } else {
                Button {
                    downloadManager.downloadEpisode(article: article)
                } label: {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: size))
                        .foregroundStyle(canDownload ? Color.platformAccent : Color.secondary)
                        .symbolRenderingMode(.multicolor)
                }
                .buttonStyle(.plain)
                .disabled(!canDownload)
            }
        }
        .frame(width: size, height: size)
    }

    private func transcribingDonut(progress: Double) -> some View {
        TranscribingDonut(size: size, lineWidth: lineWidth, progress: progress)
    }

    private func donutProgress(progress: Double) -> some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.2), lineWidth: lineWidth)
                .frame(width: size - lineWidth, height: size - lineWidth)

            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(Color.platformAccent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: size - lineWidth, height: size - lineWidth)
                .rotationEffect(.degrees(-90))
                .animation(.smooth, value: progress)

            Image(systemName: "stop.fill")
                .font(.system(size: size * 0.3))
                .foregroundStyle(Color.platformAccent)
        }
    }
}

private struct TranscribingDonut: View {

    let size: CGFloat
    let lineWidth: CGFloat
    let progress: Double

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.2), lineWidth: lineWidth)
                .frame(width: size - lineWidth, height: size - lineWidth)

            if progress > 0 {
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(Color.platformAccent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .frame(width: size - lineWidth, height: size - lineWidth)
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth, value: progress)
            } else {
                Circle()
                    .stroke(Color.platformAccent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .frame(width: size - lineWidth, height: size - lineWidth)
            }

            Image(systemName: "waveform")
                .font(.system(size: size * 0.45))
                .foregroundStyle(Color.platformAccent)
                .opacity(progress > 0 ? 1.0 : (isPulsing ? 0.35 : 1.0))
        }
        .onAppear {
            guard progress <= 0 else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}
