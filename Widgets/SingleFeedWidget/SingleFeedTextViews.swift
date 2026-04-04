import SwiftUI

struct SingleFeedMediumTextView: View {

    let entry: SingleFeedEntry

    var body: some View {
        if entry.articles.isEmpty {
            emptyView(iconSize: 22, textSize: 12)
        } else {
            VStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(entry.articles.prefix(4)) { article in
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

                        if article.id != entry.articles.prefix(4).last?.id {
                            Divider()
                        }
                    }
                }
                Spacer(minLength: 0)
                FeedTitleBar(title: entry.feedTitle, feedID: entry.feedID, currentPage: entry.currentPage, totalPages: entry.totalPages)
            }
            .padding(16)
        }
    }
}

struct SingleFeedLargeTextView: View {

    let entry: SingleFeedEntry

    var body: some View {
        if entry.articles.isEmpty {
            emptyView(iconSize: 34, textSize: 15)
        } else {
            VStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(entry.articles.prefix(9)) { article in
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

                        if article.id != entry.articles.prefix(9).last?.id {
                            Divider()
                        }
                    }
                }
                Spacer(minLength: 0)
                FeedTitleBar(title: entry.feedTitle, feedID: entry.feedID, currentPage: entry.currentPage, totalPages: entry.totalPages)
            }
            .padding(16)
        }
    }
}
