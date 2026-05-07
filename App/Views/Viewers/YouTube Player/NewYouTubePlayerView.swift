import AVKit
import SwiftUI

/// Experimental YouTube player that uses `AVPlayer` to stream the HLS manifest
/// fetched through `YouTubeBrowseClient`. Streaming only — no downloads.
struct NewYouTubePlayerView: View {

    @Environment(FeedManager.self) private var feedManager
    @Environment(\.dismiss) private var dismissSheet
    let article: Article
    let showsDismissButton: Bool

    @State private var loadState: LoadState = .loading
    @State private var feed: Feed?
    @State private var icon: UIImage?
    @State private var acronymIcon: UIImage?
    @State private var isBookmarked = false

    init(article: Article, showsDismissButton: Bool = false) {
        self.article = article
        self.showsDismissButton = showsDismissButton
    }

    enum LoadState {
        case loading
        case ready(URL)
        case failed
    }

    var body: some View {
        VStack(spacing: 0) {
            playerContainer
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .clipped()

            ScrollView(.vertical) {
                VStack(spacing: 16) {
                    WordWrappingText(
                        article.title,
                        font: .preferredFont(forTextStyle: .title2, weight: .bold)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()

                    if let feed {
                        HStack(alignment: .center, spacing: 12) {
                            feedAvatarView
                            VStack(alignment: .leading, spacing: 2) {
                                Text(feed.title)
                                    .font(.subheadline.bold())
                                if let date = article.publishedDate {
                                    RelativeTimeText(date: date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                    }

                    if let summary = article.summary ?? article.content, !summary.isEmpty {
                        Divider()
                        Text(summary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer().frame(height: 32)
                }
                .padding()
            }
            .ignoresSafeArea(.all, edges: [.top])
        }
        .sakuraBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .task { await loadStream() }
    }

    @ViewBuilder
    private var playerContainer: some View {
        switch loadState {
        case .loading:
            Color.black.overlay {
                ProgressView()
                    .tint(.white)
            }
        case .ready(let url):
            NewYouTubePlayerRepresentable(url: url)
        case .failed:
            Color.black.overlay {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                    Text(String(localized: "YouTube.NewPlayer.LoadFailed", table: "Integrations"))
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var feedAvatarView: some View {
        if let icon {
            IconImage(icon, size: 36, circle: true, skipInset: true)
        } else if let acronymIcon {
            IconImage(acronymIcon, size: 36, circle: true, skipInset: true)
        } else if let feed {
            InitialsAvatarView(feed.title, size: 36, circle: true)
        } else {
            Circle()
                .fill(.secondary.opacity(0.2))
                .frame(width: 36, height: 36)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if showsDismissButton {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismissSheet()
                } label: {
                    Image(systemName: "chevron.down")
                }
                .accessibilityLabel(String(localized: "Article.Dismiss", table: "Articles"))
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            if !article.isEphemeral {
                Button {
                    isBookmarked.toggle()
                    feedManager.toggleBookmark(article)
                } label: {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                }
            }
        }
    }

    private func loadStream() async {
        isBookmarked = feedManager.isBookmarked(article)
        if let loadedFeed = feedManager.feed(forArticle: article) {
            feed = loadedFeed
            if let data = loadedFeed.acronymIcon {
                acronymIcon = UIImage(data: data)
            }
            icon = await IconCache.shared.icon(for: loadedFeed)
        }

        guard let videoId = YouTubeStreamFetcher.parseVideoIdentifier(article.url) else {
            loadState = .failed
            return
        }

        do {
            let fetcher = await YouTubeStreamFetcher.bootstrap()
            let masterURL = try await fetcher.hlsMasterURL(videoId: videoId)
            loadState = .ready(masterURL)
        } catch {
            log("YT NewPlayer", "Failed to resolve stream: \(error)")
            loadState = .failed
        }
    }
}
