import SwiftUI

struct PodcastStyleView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.zoomNamespace) private var zoomNamespace
    @Environment(\.iPadArticleSelection) private var iPadArticleSelection
    let articles: [Article]
    var onLoadMore: (() -> Void)?

    var body: some View {
        List {
            ForEach(articles) { article in
                ZStack {
                    if let iPadArticleSelection {
                        Button {
                            feedManager.markRead(article)
                            iPadArticleSelection.wrappedValue = article
                        } label: {
                            EmptyView()
                        }
                        .opacity(0)
                    } else {
                        NavigationLink(value: article) {
                            EmptyView()
                        }
                        .opacity(0)
                    }

                    PodcastEpisodeRow(article: article)
                        .zoomSource(id: article.id, namespace: zoomNamespace)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 16))
                .swipeActions(edge: .leading) {
                    Button {
                        withAnimation(.smooth.speed(2.0)) {
                            feedManager.toggleRead(article)
                        }
                    } label: {
                        Image(systemName: article.isRead ? "arrow.uturn.backward" : "checkmark")
                    }
                    .tint(.blue)
                }
                .contextMenu {
                    Button {
                        feedManager.toggleRead(article)
                    } label: {
                        Label(
                            article.isRead
                                ? String(localized: "Article.MarkUnplayed")
                                : String(localized: "Article.MarkPlayed"),
                            systemImage: article.isRead ? "arrow.uturn.backward" : "checkmark"
                        )
                    }
                    Divider()
                    Button {
                        feedManager.toggleBookmark(article)
                    } label: {
                        Label(
                            article.isBookmarked
                                ? String(localized: "Article.RemoveBookmark")
                                : String(localized: "Article.Bookmark"),
                            systemImage: article.isBookmarked ? "bookmark.fill" : "bookmark"
                        )
                    }
                    Button {
                        UIPasteboard.general.string = article.url
                    } label: {
                        Label("Article.CopyLink", systemImage: "link")
                    }
                    if let shareURL = URL(string: article.url) {
                        ShareLink(item: shareURL) {
                            Label("Article.Share", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            if let onLoadMore {
                LoadPreviousArticlesButton(action: onLoadMore)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }
}

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
            // Episode artwork
            if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                CachedAsyncImage(url: url) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.secondary.opacity(0.15))
                }
                .frame(width: 60, height: 60)
                .clipShape(.rect(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
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
                    .fontWeight(article.isRead ? .regular : .semibold)
                    .foregroundStyle(article.isRead ? .secondary : .primary)
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
            return String(localized: "Podcast.Duration.HoursMinutes.\(hours).\(minutes)")
        }
        return String(localized: "Podcast.Duration.Minutes.\(minutes)")
    }
}
