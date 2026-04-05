import SwiftUI

struct SingleFeedMediumTextView: View {

    let entry: SingleFeedEntry

    private var articleCount: Int {
        UIDevice.current.userInterfaceIdiom == .pad ? 2 : 3
    }

    var body: some View {
        if entry.articles.isEmpty {
            emptyView(iconSize: 22, textSize: 12)
        } else {
            VStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(entry.articles.prefix(articleCount)) { article in
                        Link(destination: URL(string: "sakura://article/\(article.id)")!) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(article.title)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                                if let date = article.publishedDate {
                                    Text(date, style: .relative)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if article.id != entry.articles.prefix(articleCount).last?.id {
                            Divider()
                        }
                    }
                }
                FeedTitleBar(
                    title: entry.feedTitle,
                    feedID: entry.feedID,
                    currentPage: entry.currentPage,
                    totalPages: entry.totalPages
                )
            }
            .padding(16)
        }
    }
}

struct SingleFeedLargeTextView: View {

    let entry: SingleFeedEntry

    private var articleCount: Int {
        UIDevice.current.userInterfaceIdiom == .pad ? 7 : 8
    }

    var body: some View {
        if entry.articles.isEmpty {
            emptyView(iconSize: 34, textSize: 15)
        } else {
            VStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(entry.articles.prefix(articleCount)) { article in
                        Link(destination: URL(string: "sakura://article/\(article.id)")!) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(article.title)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(2)
                                if let date = article.publishedDate {
                                    Text(date, style: .relative)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if article.id != entry.articles.prefix(articleCount).last?.id {
                            Divider()
                        }
                    }
                }
                FeedTitleBar(
                    title: entry.feedTitle,
                    feedID: entry.feedID,
                    currentPage: entry.currentPage,
                    totalPages: entry.totalPages
                )
            }
            .padding(16)
        }
    }
}
