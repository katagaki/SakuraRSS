import SwiftUI

struct SingleFeedMediumThumbnailsView: View {

    let entry: SingleFeedEntry

    var body: some View {
        if entry.articles.isEmpty {
            emptyView(iconSize: 22, textSize: 12)
        } else {
            let items = Array(entry.articles.prefix(2))
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    ForEach(items) { article in
                        SingleFeedThumbnailCell(article: article, feedTitle: entry.feedTitle)
                    }
                }
                FeedTitleBar(title: entry.feedTitle, feedID: entry.feedID, currentPage: entry.currentPage, totalPages: entry.totalPages)
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
            let items = Array(entry.articles.prefix(4))
            let topRow = Array(items.prefix(2))
            let bottomRow = Array(items.dropFirst(2))

            VStack(spacing: 4) {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        ForEach(topRow) { article in
                            SingleFeedThumbnailCell(article: article, feedTitle: entry.feedTitle)
                        }
                    }
                    if !bottomRow.isEmpty {
                        HStack(spacing: 10) {
                            ForEach(bottomRow) { article in
                                SingleFeedThumbnailCell(article: article, feedTitle: entry.feedTitle)
                            }
                            if bottomRow.count < 2 {
                                Color.clear
                            }
                        }
                    }
                }
                FeedTitleBar(title: entry.feedTitle, feedID: entry.feedID, currentPage: entry.currentPage, totalPages: entry.totalPages)
            }
            .padding(16)
        }
    }
}
