import SwiftUI

struct PodcastEpisodeView: View {

    @Environment(FeedManager.self) var feedManager
    let article: Article
    private let audioPlayer = AudioPlayer.shared

    @State private var favicon: UIImage?
    @State private var feedName: String?

    private var isThisEpisode: Bool {
        audioPlayer.currentArticleID == article.id
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Artwork
                if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                    CachedAsyncImage(url: url) {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.secondary.opacity(0.15))
                            .aspectRatio(1, contentMode: .fit)
                    }
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 8, y: 4)
                    .padding(.horizontal, 40)
                }

                // Title and metadata
                VStack(spacing: 8) {
                    Text(article.title)
                        .font(.title3)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 8) {
                        if let favicon {
                            FaviconImage(favicon, size: 18, cornerRadius: 4, skipInset: true)
                        } else if let feedName {
                            InitialsAvatarView(feedName, size: 18, cornerRadius: 4)
                        }

                        if let feedName {
                            Text(feedName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if let date = article.publishedDate {
                            Text("·")
                                .foregroundStyle(.tertiary)
                            RelativeTimeText(date: date)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal)

                // Playback controls
                if isThisEpisode {
                    VStack(spacing: 12) {
                        // Seek bar
                        SeekBarView(
                            currentTime: Binding(
                                get: { audioPlayer.currentTime },
                                set: { audioPlayer.currentTime = $0 }
                            ),
                            duration: audioPlayer.duration,
                            onSeek: { audioPlayer.seek(to: $0) }
                        )

                        // Transport controls
                        HStack(spacing: 40) {
                            Button { audioPlayer.skipBackward() } label: {
                                Image(systemName: "gobackward.15")
                                    .font(.title2)
                            }

                            Button { audioPlayer.togglePlayPause() } label: {
                                Image(systemName: audioPlayer.isPlaying
                                      ? "pause.circle.fill"
                                      : "play.circle.fill")
                                    .font(.system(size: 56))
                            }

                            Button { audioPlayer.skipForward() } label: {
                                Image(systemName: "goforward.30")
                                    .font(.title2)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                    .padding(.horizontal)
                } else {
                    // Not currently playing - show play button
                    Button {
                        startPlayback()
                    } label: {
                        Label(String(localized: "Podcast.Play"), systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)

                    if audioPlayer.isLoading && audioPlayer.currentArticleID == article.id {
                        ProgressView()
                    }
                }

                // Episode description
                if let summary = article.summary, !summary.isEmpty {
                    SelectableText(summary)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .sakuraBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    feedManager.toggleBookmark(article)
                } label: {
                    Image(systemName: article.isBookmarked ? "bookmark.fill" : "bookmark")
                }
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let shareURL = URL(string: article.url) {
                    ShareLink(item: shareURL) {
                        Label(String(localized: "Article.Share"), systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .task {
            feedManager.markRead(article)
            if let feed = feedManager.feed(forArticle: article) {
                feedName = feed.title
                favicon = await FaviconCache.shared.favicon(for: feed.domain, siteURL: feed.siteURL)
            }
        }
    }

    private func startPlayback() {
        guard let audioURLString = article.audioURL,
              let audioURL = URL(string: audioURLString) else { return }
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
