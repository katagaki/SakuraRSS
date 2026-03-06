import SwiftUI

// MARK: - Feed Navigation Environment

private struct FeedNavigationActionKey: EnvironmentKey {
    static let defaultValue: ((Feed) -> Void)? = nil
}

extension EnvironmentValues {
    var navigateToFeed: ((Feed) -> Void)? {
        get { self[FeedNavigationActionKey.self] }
        set { self[FeedNavigationActionKey.self] = newValue }
    }
}

struct FeedStyleView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.zoomNamespace) private var zoomNamespace
    let articles: [Article]
    var onLoadMore: (() -> Void)?

    var body: some View {
        List {
            ForEach(articles) { article in
                ZStack {
                    ArticleLink(article: article) {
                        EmptyView()
                    }
                    .opacity(0)

                    FeedArticleRow(article: article)
                        .zoomSource(id: article.id, namespace: zoomNamespace)
                }
                .padding(.horizontal, 12)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0))
                .listRowSeparator(.hidden, edges: .top)
                .listRowSeparator(.visible, edges: .bottom)
                .alignmentGuide(.listRowSeparatorLeading) { _ in
                    return 0
                }
                .alignmentGuide(.listRowSeparatorTrailing) { dimensions in
                    return dimensions.width
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

struct FeedArticleRow: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.openURL) var openURL
    @Environment(\.navigateToFeed) var navigateToFeed
    let article: Article
    @AppStorage("Labs.YouTubePlayer") private var youTubePlayerEnabled: Bool = false
    @State private var favicon: UIImage?
    @State private var feedName: String?
    @State private var acronymIcon: UIImage?
    @State private var skipFaviconInset = false
    @State private var preferTitle = false
    @State private var feed: Feed?
    @State private var showYouTubePlayer = false

    @ViewBuilder
    private var feedAvatarView: some View {
        if let favicon = favicon {
            FaviconImage(favicon, size: 40, circle: true, skipInset: skipFaviconInset)
        } else if let acronymIcon {
            FaviconImage(acronymIcon, size: 40, circle: true, skipInset: true)
        } else if let feedName {
            InitialsAvatarView(feedName, size: 40, circle: true)
        } else {
            Circle()
                .fill(.secondary.opacity(0.2))
                .frame(width: 40, height: 40)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let feed, let navigateToFeed {
                Button { navigateToFeed(feed) } label: { feedAvatarView }
                    .buttonStyle(.plain)
            } else {
                feedAvatarView
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    if let feed, let feedName, let navigateToFeed {
                        Button { navigateToFeed(feed) } label: {
                            Text(feedName)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    } else if let feedName {
                        Text(feedName)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }

                    if let date = article.publishedDate {
                        Text("·")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        RelativeTimeText(date: date)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !article.isRead {
                        Circle()
                            .fill(.blue)
                            .frame(width: 8, height: 8)
                    }
                }

                Group {
                    if !preferTitle, article.hasMeaningfulSummary, let summary = article.summary {
                        Text(ContentBlock.stripMarkdown(summary))
                    } else {
                        Text(article.title)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(3)

                if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                    CachedAsyncImage(url: url) {
                        Color.secondary.opacity(0.1)
                            .frame(height: 180)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 180)
                    .clipShape(.rect(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.thickMaterial, lineWidth: 0.5)
                    }
                    .padding(.top, 4)
                }

                HStack {
                    Button {
                        if article.isYouTubeURL && youTubePlayerEnabled {
                            showYouTubePlayer = true
                        } else if article.isYouTubeURL {
                            YouTubeHelper.openInApp(url: article.url)
                        } else if let url = URL(string: article.url) {
                            openURL(url)
                        }
                    } label: {
                        Image(
                            systemName: (
                                article.isYouTubeURL && YouTubeHelper.isAppInstalled ? "play.rectangle" : "safari"
                            )
                        )
                    }
                    .buttonStyle(.plain)
                    .fullScreenCover(isPresented: $showYouTubePlayer) {
                        YouTubePlayerView(article: article)
                    }

                    Spacer()

                    Button {
                        UIPasteboard.general.string = article.url
                    } label: {
                        Image(systemName: "square.on.square")
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        feedManager.toggleRead(article)
                    } label: {
                        Image(
                            systemName: article.isRead
                                ? "envelope" : "envelope.open"
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        feedManager.toggleBookmark(article)
                    } label: {
                        Image(systemName: article.isBookmarked ? "bookmark.fill" : "bookmark")
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    if let shareURL = URL(string: article.url) {
                        ShareLink(item: shareURL) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            }
        }
        .task {
            if let loadedFeed = feedManager.feed(forArticle: article) {
                feed = loadedFeed
                feedName = loadedFeed.title
                if let data = loadedFeed.acronymIcon {
                    acronymIcon = UIImage(data: data)
                }
                skipFaviconInset = loadedFeed.isVideoFeed || loadedFeed.isXFeed
                    || FullFaviconDomains.shouldUseFullImage(feedDomain: loadedFeed.domain)
                preferTitle = TitleOnlyDomains.shouldPreferTitle(feedDomain: loadedFeed.domain)
                favicon = await FaviconCache.shared.favicon(for: loadedFeed)
            }
        }
    }
}
