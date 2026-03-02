import SwiftUI

struct FeedStyleView: View {

    @Environment(FeedManager.self) var feedManager
    let articles: [Article]

    var body: some View {
        List(articles) { article in
            ZStack {
                ArticleLink(article: article) {
                    EmptyView()
                }
                .opacity(0)

                FeedArticleRow(article: article)
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
        .listStyle(.plain)
    }
}

struct FeedArticleRow: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.openURL) var openURL
    let article: Article
    @State private var favicon: UIImage?
    @State private var feedName: String?
    @State private var isYouTube = false
    @State private var preferTitle = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let favicon = favicon {
                FaviconImage(favicon, size: 40, circle: true, skipInset: isYouTube)
            } else if let feedName {
                InitialsAvatarView(feedName, size: 40, circle: true)
            } else {
                Circle()
                    .fill(.secondary.opacity(0.2))
                    .frame(width: 40, height: 40)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    if let feedName {
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
                    if !preferTitle, let summary = article.summary {
                        Text(summary)
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
                        if article.isYouTubeURL {
                            YouTubeHelper.openInApp(url: article.url)
                        } else if let url = URL(string: article.url) {
                            openURL(url)
                        }
                    } label: {
                        Image(systemName: article.isYouTubeURL ? "play.rectangle.fill" : "safari")
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        UIPasteboard.general.string = article.url
                    } label: {
                        Image(systemName: "square.on.square")
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
            if let feed = feedManager.feed(forArticle: article) {
                favicon = await FaviconCache.shared.favicon(for: feed.domain, siteURL: feed.siteURL)
                feedName = feed.title
                isYouTube = feed.isVideoFeed
                preferTitle = TitleOnlyDomains.shouldPreferTitle(feedDomain: feed.domain)
            }
        }
    }
}
