import SwiftUI
import Hanami

struct SimilarArticleCard: View {

    @Environment(\.zoomNamespace) private var zoomNamespace
    let item: SimilarArticleItem

    private let cardWidth: CGFloat = 240
    private let imageHeight: CGFloat = 135

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardVisual
                .frame(width: cardWidth, height: imageHeight)
                .clipShape(.rect(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.primary.opacity(0.2), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                .zoomSource(id: item.article.id, namespace: zoomNamespace)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.article.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                Text(item.feedName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: cardWidth, alignment: .leading)
        }
    }

    @ViewBuilder
    private var cardVisual: some View {
        if let imageURL = item.article.imageURL, let url = URL(string: imageURL) {
            CachedAsyncImage(url: url, alignment: .top) {
                thumbnailBackground
            }
        } else {
            thumbnailBackground
        }
    }

    private var thumbnailBackground: some View {
        FeedIconPlaceholder(
            icon: item.icon,
            acronymIcon: nil,
            feedName: item.feedName,
            isCircleIcon: item.isCircleIcon,
            iconSize: imageHeight * 0.5,
            fallback: .symbol("doc.text")
        )
    }
}
