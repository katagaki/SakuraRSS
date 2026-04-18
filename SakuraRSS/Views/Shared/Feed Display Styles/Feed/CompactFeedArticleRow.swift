import SwiftUI

struct CompactFeedArticleRow: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.openURL) var openURL
    @Environment(\.navigateToFeed) var navigateToFeed
    let article: Article
    var onShowYouTubePlayer: (() -> Void)?
    @AppStorage("YouTube.OpenMode") private var youTubeOpenMode: YouTubeOpenMode = .inAppPlayer
    @State private var favicon: UIImage?
    @State private var feedName: String?
    @State private var acronymIcon: UIImage?
    @State private var skipFaviconInset = false
    @State private var feed: Feed?
    @State private var showSafari = false

    private var opensInExternalApp: Bool {
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
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            feedHeaderRow

            HStack(alignment: .top, spacing: 10) {
                Text(article.title.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

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

            HStack(spacing: 10) {
                Button {
                    if article.isYouTubeURL && youTubeOpenMode == .inAppPlayer {
                        onShowYouTubePlayer?()
                    } else if article.isYouTubeURL && youTubeOpenMode == .youTubeApp {
                        YouTubeHelper.openInApp(url: article.url)
                    } else if article.isYouTubeURL && youTubeOpenMode == .browser {
                        showSafari = true
                    } else if let url = URL(string: article.url) {
                        openURL(url)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(
                            systemName: (
                                article.isYouTubeURL && YouTubeHelper.isAppInstalled
                                    ? "play.rectangle"
                                    : (opensInExternalApp ? "arrow.up.forward.app" : "safari")
                            )
                        )
                        Text(
                            opensInExternalApp ? String(
                                localized: "OpenInApp",
                                table: "Articles"
                            ) : String(localized: "OpenInBrowser", table: "Articles")
                        )
                            .lineLimit(1)
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(.secondary.opacity(0.15), in: .capsule)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    feedManager.toggleRead(article)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: article.isRead ? "envelope" : "envelope.open")
                            .offset(y: article.isRead ? 0 : -1)
                        Text(
                            article.isRead ? String(
                                localized: "Article.MarkUnread",
                                table: "Articles"
                            ) : String(
                                localized: "Article.MarkRead",
                                table: "Articles"
                            )
                        )
                            .lineLimit(1)
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(.secondary.opacity(0.15), in: .capsule)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)

                Spacer()

                Menu {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        feedManager.toggleBookmark(article)
                    } label: {
                        Label(
                            article.isBookmarked ? String(
                                localized: "Article.RemoveBookmark",
                                table: "Articles"
                            ) : String(
                                localized: "Article.Bookmark",
                                table: "Articles"
                            ),
                            systemImage: article.isBookmarked ? "bookmark.fill" : "bookmark"
                        )
                    }

                    if let shareURL = URL(string: article.url) {
                        ShareLink(item: shareURL) {
                            Label(
                                String(
                                    localized: "Article.Share",
                                    table: "Articles"
                                ),
                                systemImage: "square.and.arrow.up"
                            )
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
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
