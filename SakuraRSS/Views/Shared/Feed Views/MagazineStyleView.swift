import SwiftUI

struct MagazineStyleView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.zoomNamespace) private var zoomNamespace
    let articles: [Article]
    var onLoadMore: (() -> Void)?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView(.vertical) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(articles) { article in
                    ArticleLink(article: article) {
                        MagazineArticleCard(article: article)
                            .zoomSource(id: article.id, namespace: zoomNamespace)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            feedManager.toggleRead(article)
                        } label: {
                            Label(
                                article.isRead
                                    ? String(localized: "Article.MarkUnread")
                                    : String(localized: "Article.MarkRead"),
                                systemImage: article.isRead
                                    ? "envelope" : "envelope.open"
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom)
            if let onLoadMore {
                LoadPreviousArticlesButton(action: onLoadMore)
                    .padding(.horizontal, 16)
                    .padding(.bottom)
            }
        }
    }
}

struct MagazineArticleCard: View {

    @Environment(FeedManager.self) var feedManager
    let article: Article
    @State private var favicon: UIImage?
    @State private var feedName: String?
    @State private var acronymIcon: UIImage?
    @State private var skipFaviconInset = false
    @State private var isVideoFeed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomLeading) {
                if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                    Color.clear
                        .frame(height: 120)
                        .overlay {
                            CachedAsyncImage(url: url) {
                                Rectangle()
                                    .fill(.secondary.opacity(0.15))
                            }
                        }
                        .clipped()
                        .clipShape(.rect(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.secondary.opacity(0.15))
                        .frame(height: 120)
                }

                if let favicon = favicon {
                    FaviconImage(favicon, size: 20, cornerRadius: 4,
                                 circle: isVideoFeed, skipInset: skipFaviconInset)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .padding(6)
                } else if let acronymIcon {
                    FaviconImage(acronymIcon, size: 20, cornerRadius: 4,
                                 circle: isVideoFeed, skipInset: true)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .padding(6)
                } else if let feedName {
                    InitialsAvatarView(feedName, size: 20, circle: isVideoFeed, cornerRadius: 4)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .padding(6)
                }
            }

            HStack(spacing: 4) {
                Text(article.title)
                    .font(.subheadline)
                    .fontWeight(article.isRead ? .regular : .semibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(article.isRead ? .secondary : .primary)

                Spacer(minLength: 0)
            }

            if let date = article.publishedDate {
                RelativeTimeText(date: date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(.rect)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        .task {
            if let feed = feedManager.feed(forArticle: article) {
                feedName = feed.title
                if let data = feed.acronymIcon {
                    acronymIcon = UIImage(data: data)
                }
                isVideoFeed = feed.isVideoFeed || feed.isXFeed
                skipFaviconInset = feed.isVideoFeed || feed.isXFeed
                    || FullFaviconDomains.shouldUseFullImage(feedDomain: feed.domain)
                favicon = await FaviconCache.shared.favicon(for: feed.domain, siteURL: feed.siteURL)
            }
        }
    }
}
