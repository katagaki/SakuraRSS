import Hanami
import SwiftUI

struct TodayCard: View {

    let article: Article
    let feedTitle: String?
    var isSquare = false

    private var width: CGFloat { isSquare ? 160 : 240 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TodayThumbnail(urlString: article.imageURL)
                .frame(width: width, height: isSquare ? width : width * 9 / 16)
                .clipShape(.rect(cornerRadius: 10))
            Text(article.displayTitle)
                .font(.callout)
                .fontWeight(.medium)
                .lineLimit(2, reservesSpace: true)
            if let feedTitle {
                Text(feedTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: width, alignment: .leading)
        .contentShape(.rect)
    }
}
