import SwiftUI

struct GridArticleCell: View {

    let article: Article

    var body: some View {
        Group {
            if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                CachedAsyncImage(url: url) {
                    Rectangle()
                        .fill(.secondary.opacity(0.15))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
        .contentShape(.rect)
        .overlay(alignment: .topTrailing) {
            if article.carouselImageURLs.count > 1 {
                Image(systemName: "square.on.square.fill")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
                    .padding(6)
            } else if article.url.contains("/reel/") {
                Image(systemName: "play.fill")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
                    .padding(6)
            }
        }
    }
}
