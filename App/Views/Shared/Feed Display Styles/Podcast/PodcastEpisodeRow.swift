import SwiftUI

struct PodcastEpisodeRow: View {

    @Environment(FeedManager.self) var feedManager
    let article: Article
    private let audioPlayer = AudioPlayer.shared
    private let downloadManager = PodcastDownloadManager.shared
    private let networkMonitor = NetworkMonitor.shared

    private var isCurrentlyPlaying: Bool {
        audioPlayer.currentArticleID == article.id
    }

    private var isDownloaded: Bool {
        downloadManager.isDownloaded(articleID: article.id)
    }

    private var isOffline: Bool {
        !networkMonitor.isOnline
    }

    private var canPlay: Bool {
        isDownloaded || !isOffline
    }

    var body: some View {
        HStack(spacing: 12) {
            if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                CachedAsyncImage(url: url) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.secondary.opacity(0.15))
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.secondary.opacity(0.25), lineWidth: 1)
                }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.secondary.opacity(0.15))
                    .frame(width: 60, height: 60)
            }

            VStack(alignment: .leading, spacing: 4) {
                if let date = article.publishedDate {
                    Text(date.formatted(date: .abbreviated, time: .omitted).uppercased())
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                }

                Text(article.title)
                    .font(.subheadline)
                    .fontWeight(feedManager.isRead(article) ? .regular : .semibold)
                    .foregroundStyle(feedManager.isRead(article) ? .secondary : .primary)
                    .lineLimit(2)

                if let duration = article.duration {
                    Text(formatDuration(duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            if article.isPodcastEpisode {
                PodcastDownloadButton(article: article, size: 28, lineWidth: 2.5)
                Button {
                    handlePlay()
                } label: {
                    Image(systemName: isCurrentlyPlaying && audioPlayer.isPlaying
                          ? "pause.circle.fill"
                          : "play.circle.fill")
                        .font(.title)
                        .foregroundStyle(.accent)
                        .symbolRenderingMode(.multicolor)
                }
                .buttonStyle(.plain)
                .disabled(!canPlay && !isCurrentlyPlaying)
            }
        }
    }

    private func handlePlay() {
        if isCurrentlyPlaying {
            audioPlayer.togglePlayPause()
        } else {
            let playbackURL: URL
            if let localURL = downloadManager.localFileURL(for: article.id) {
                playbackURL = localURL
            } else if let audioURLString = article.audioURL,
                      let audioURL = URL(string: audioURLString) {
                playbackURL = audioURL
            } else {
                return
            }
            feedManager.markRead(article)
            let feed = feedManager.feed(forArticle: article)
            audioPlayer.play(
                url: playbackURL,
                articleID: article.id,
                feedID: article.feedID,
                episodeTitle: article.title,
                feedTitle: feed?.title ?? "",
                artworkURL: article.imageURL,
                feedIconURL: feed?.faviconURL,
                episodeDuration: article.duration
            )
        }
    }

    private func formatDuration(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return String(localized: "Duration.HoursMinutes.\(hours).\(minutes)", table: "Podcast")
        }
        return String(localized: "Duration.Minutes.\(minutes)", table: "Podcast")
    }
}
