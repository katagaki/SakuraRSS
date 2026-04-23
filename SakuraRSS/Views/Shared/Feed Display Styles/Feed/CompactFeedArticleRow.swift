import SwiftUI

struct CompactFeedArticleRow: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.navigateToFeed) var navigateToFeed
    let article: Article
    var onShowYouTubePlayer: (() -> Void)?
    @State private var favicon: UIImage?
    @State private var feedName: String?
    @State private var acronymIcon: UIImage?
    @State private var skipFaviconInset = false
    @State private var feed: Feed?
    @State private var showSafari = false

    var opensInExternalApp: Bool {
        if feed?.isRedditFeed == true { return RedditHelper.isAppInstalled }
        if feed?.isXFeed == true { return XHelper.isAppInstalled }
        if feed?.isInstagramFeed == true { return InstagramHelper.isAppInstalled }
        return false
    }

    @ViewBuilder
    private var feedAvatarView: some View {
        if let favicon = favicon {
            FaviconImage(favicon, size: 20, circle: true, skipInset: skipFaviconInset)
        } else if let acronymIcon {
            FaviconImage(acronymIcon, size: 20, circle: true, skipInset: true)
        } else if let feedName {
            InitialsAvatarView(feedName, size: 20, circle: true)
        } else {
            Circle()
                .fill(.secondary.opacity(0.2))
                .frame(width: 20, height: 20)
        }
    }

    @ViewBuilder
    private var feedHeaderRow: some View {
        HStack(spacing: 6) {
            if let feed, let navigateToFeed {
                Button { navigateToFeed(feed) } label: {
                    HStack(spacing: 6) {
                        feedAvatarView
                        if let feedName {
                            Text(feedName)
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                    }
                }
                .buttonStyle(.plain)
            } else {
                feedAvatarView
                if let feedName {
                    Text(feedName)
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }

            if let date = article.publishedDate {
                Text("·")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                RelativeTimeText(date: date)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            if !article.isRead {
                UnreadDotView(isRead: article.isRead)
            }

            CompactFeedArticleRowOverflowMenu(article: article)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let imageURL = article.imageURL, let url = URL(string: imageURL) {
            CachedAsyncImage(url: url, alignment: .center, placeholder: {
                Color.secondary.opacity(0.1)
                    .frame(width: 72, height: 72)
            })
            .frame(width: 72, height: 72)
            .clipShape(.rect(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.quaternary, lineWidth: 0.5)
            }
            .overlay {
                if feed?.isVideoFeed == true || feed?.isPodcast == true {
                    Image(systemName: "play.fill")
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .padding(8)
                        .background(.ultraThinMaterial, in: .circle)
                }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            feedHeaderRow

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(article.title.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .truncationMode(.tail)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 0)

                    CompactFeedArticleRowActions(
                        article: article,
                        opensInExternalApp: opensInExternalApp,
                        onShowYouTubePlayer: onShowYouTubePlayer,
                        onShowSafari: { showSafari = true }
                    )
                }
                .frame(maxHeight: .infinity)

                thumbnail
            }
        }
        .task {
            if let loadedFeed = feedManager.feed(forArticle: article) {
                feed = loadedFeed
                feedName = loadedFeed.title
                if let data = loadedFeed.acronymIcon {
                    acronymIcon = UIImage(data: data)
                }
                skipFaviconInset = loadedFeed.isVideoFeed || loadedFeed.isXFeed || loadedFeed.isInstagramFeed
                    || FaviconNoInsetDomains.shouldUseFullImage(feedDomain: loadedFeed.domain)
                favicon = await FaviconCache.shared.favicon(for: loadedFeed)
            }
        }
        .sheet(isPresented: $showSafari) {
            if let url = URL(string: article.url) {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
    }
}
