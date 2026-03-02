import SwiftUI

struct ArticleListView: View {

    @Environment(FeedManager.self) var feedManager
    let articles: [Article]
    let title: String

    var body: some View {
        Group {
            switch feedManager.displayStyle {
            case .inbox:
                InboxStyleView(articles: articles)
            case .magazine:
                MagazineStyleView(articles: articles)
            case .compact:
                CompactStyleView(articles: articles)
            }
        }
        .scrollContentBackground(.hidden)
        .sakuraBackground()
        .navigationTitle(title)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Picker(String(localized: "Articles.DisplayStyle"), selection: Bindable(feedManager).displayStyle) {
                        Label(String(localized: "Articles.Style.Inbox"), systemImage: "list.bullet")
                            .tag(FeedDisplayStyle.inbox)
                        Label(String(localized: "Articles.Style.Magazine"), systemImage: "rectangle.grid.2x2")
                            .tag(FeedDisplayStyle.magazine)
                        Label(String(localized: "Articles.Style.Compact"), systemImage: "list.dash")
                            .tag(FeedDisplayStyle.compact)
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                }
            }
        }
        .overlay {
            if articles.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "Articles.Empty.Title"),
                          systemImage: "doc.text")
                } description: {
                    Text(String(localized: "Articles.Empty.Description"))
                }
            }
        }
    }
}

// MARK: - Inbox Style

struct InboxStyleView: View {

    @Environment(FeedManager.self) var feedManager
    let articles: [Article]

    var body: some View {
        List(articles) { article in
            NavigationLink {
                ArticleDetailView(article: article)
            } label: {
                InboxArticleRow(article: article)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        }
        .listStyle(.plain)
    }
}

struct InboxArticleRow: View {

    @Environment(FeedManager.self) var feedManager
    let article: Article
    @State private var favicon: UIImage?

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Circle()
                .fill(article.isRead ? .clear : .blue)
                .frame(width: 8, height: 8)
                .padding(.leading, -4)
                .padding(.top, 6)

            if let favicon = favicon {
                Image(uiImage: favicon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .padding(.top, 2)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(article.title)
                    .font(.subheadline)
                    .fontWeight(article.isRead ? .regular : .semibold)
                    .lineLimit(2)
                    .foregroundStyle(article.isRead ? .secondary : .primary)

                if let summary = article.summary {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    if let author = article.author {
                        Text(author)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    if let date = article.publishedDate {
                        Text(date, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.secondary.opacity(0.1)
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .task {
            if let feed = feedManager.feed(forArticle: article) {
                favicon = await FaviconCache.shared.favicon(for: feed.domain)
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                feedManager.toggleBookmark(article)
            } label: {
                Image(systemName: article.isBookmarked ? "bookmark.slash" : "bookmark")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing) {
            Button {
                feedManager.markRead(article)
            } label: {
                Image(systemName: "checkmark.circle")
            }
            .tint(.blue)
        }
    }
}

// MARK: - Magazine Style

struct MagazineStyleView: View {

    @Environment(FeedManager.self) var feedManager
    let articles: [Article]

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ScrollView(.vertical) {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(articles) { article in
                    NavigationLink {
                        ArticleDetailView(article: article)
                    } label: {
                        MagazineArticleCard(article: article)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical)
        }
    }
}

struct MagazineArticleCard: View {

    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                Color.clear
                    .frame(height: 120)
                    .overlay {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(.secondary.opacity(0.1))
                        }
                    }
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Text(article.title)
                .font(.subheadline)
                .fontWeight(article.isRead ? .regular : .semibold)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .foregroundStyle(article.isRead ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let date = article.publishedDate {
                Text(date, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .background(.background)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

// MARK: - Compact Style

struct CompactStyleView: View {

    @Environment(FeedManager.self) var feedManager
    let articles: [Article]

    var body: some View {
        List(articles) { article in
            NavigationLink {
                ArticleDetailView(article: article)
            } label: {
                HStack {
                    Text(article.title)
                        .font(.caption)
                        .fontWeight(article.isRead ? .regular : .medium)
                        .foregroundStyle(article.isRead ? .secondary : .primary)
                        .lineLimit(1)

                    Spacer()

                    if let date = article.publishedDate {
                        Text(date, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .listRowSpacing(0.0)
            .swipeActions(edge: .trailing) {
                Button {
                    feedManager.markRead(article)
                } label: {
                    Image(systemName: "checkmark.circle")
                }
                .tint(.blue)
            }
        }
        .listStyle(.plain)
    }
}
