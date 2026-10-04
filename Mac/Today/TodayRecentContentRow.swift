import Hanami
import SwiftUI

struct TodayRecentContentRow: View {

    let article: Article
    let feedTitle: String?

    var body: some View {
        HStack(spacing: 12) {
            TodayThumbnail(urlString: article.imageURL)
                .frame(width: 40, height: 40)
                .clipShape(.rect(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(article.displayTitle)
                    .font(.callout)
                    .fontWeight(.medium)
                    .lineLimit(2)
                if let feedTitle {
                    Text(feedTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(.rect)
    }
}
