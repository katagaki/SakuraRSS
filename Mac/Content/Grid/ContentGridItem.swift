import Hanami
import SwiftUI

/// One piece of content in a grid style, shaped by that style.
struct ContentGridItem: View {

    let article: Article
    let feedTitle: String?
    let isRead: Bool
    let style: FeedDisplayStyle

    var body: some View {
        switch style {
        case .photos:
            TodayThumbnail(urlString: article.imageURL)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 4))
        case .grid, .podcast:
            VStack(alignment: .leading, spacing: 6) {
                TodayThumbnail(urlString: article.imageURL)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 10))
                ContentGridCaption(article: article, feedTitle: feedTitle, isRead: isRead, titleLines: 2)
            }
        case .masonry:
            VStack(alignment: .leading, spacing: 6) {
                ContentNaturalImage(urlString: article.imageURL)
                ContentGridCaption(article: article, feedTitle: feedTitle, isRead: isRead, titleLines: 3)
            }
        case .video:
            VStack(alignment: .leading, spacing: 6) {
                TodayThumbnail(urlString: article.imageURL)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 10))
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "play.fill")
                            .font(.caption)
                            .padding(6)
                            .background(.ultraThinMaterial, in: .circle)
                            .padding(8)
                    }
                ContentGridCaption(article: article, feedTitle: feedTitle, isRead: isRead, titleLines: 2)
            }
        default:
            VStack(alignment: .leading, spacing: 8) {
                TodayThumbnail(urlString: article.imageURL)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 12))
                ContentGridCaption(article: article, feedTitle: feedTitle, isRead: isRead, titleLines: 3)
            }
        }
    }
}
