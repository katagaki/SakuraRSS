import SwiftUI

struct PodcastStyleView: View {

    @Environment(FeedManager.self) var feedManager
    let articles: [Article]
    var onLoadMore: (() -> Void)?

    var body: some View {
        List {
            ForEach(articles) { article in
                ZStack {
                    NavigationLink(value: article) {
                        EmptyView()
                    }
                    .opacity(0)

                    PodcastEpisodeRow(article: article)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 16))
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

    private var isCurrentlyPlaying: Bool {
        audioPlayer.currentArticleID == article.id
    }

    var body: some View {
        HStack(spacing: 12) {
            // Episode artwork
            if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                CachedAsyncImage(url: url) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.secondary.opacity(0.15))
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
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
        }
    }

    private func handlePlay() {
        if isCurrentlyPlaying {
            audioPlayer.togglePlayPause()
        } else if let audioURLString = article.audioURL,
                  let audioURL = URL(string: audioURLString) {
            feedManager.markRead(article)
            let feed = feedManager.feed(forArticle: article)
            audioPlayer.play(
                url: audioURL,
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
