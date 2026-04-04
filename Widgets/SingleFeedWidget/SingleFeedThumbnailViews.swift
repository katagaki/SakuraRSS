import SwiftUI

struct SingleFeedMediumThumbnailsView: View {

    let entry: SingleFeedEntry

    var body: some View {
        if entry.articles.isEmpty {
            emptyView(iconSize: 22, textSize: 12)
        } else {
            let cols = entry.columns
            let items = Array(entry.articles.prefix(cols))
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(items) { article in
                        SingleFeedThumbnailCell(article: article, feedTitle: entry.feedTitle)
                    }
                    ForEach(0..<(cols - items.count), id: \.self) { _ in
                        Color.clear
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

struct SingleFeedLargeThumbnailsView: View {

    let entry: SingleFeedEntry

    var body: some View {
        if entry.articles.isEmpty {
            emptyView(iconSize: 34, textSize: 15)
        } else {
            let cols = entry.columns
            let items = Array(entry.articles.prefix(cols * cols))
            let rows = stride(from: 0, to: items.count, by: cols).map {
                Array(items[$0..<min($0 + cols, items.count)])
            }

            VStack(spacing: 8) {
                VStack(spacing: 8) {
                    ForEach(rows, id: \.first?.id) { row in
                        HStack(spacing: 8) {
                            ForEach(row) { article in
                                SingleFeedThumbnailCell(article: article, feedTitle: entry.feedTitle)
                            }
                            ForEach(0..<(cols - row.count), id: \.self) { _ in
                                Color.clear
                            }
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
