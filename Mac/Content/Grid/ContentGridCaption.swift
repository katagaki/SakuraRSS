import Hanami
import SwiftUI

struct ContentGridCaption: View {

    let article: Article
    let feedTitle: String?
    let isRead: Bool
    let titleLines: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if !isRead {
                    Circle()
                        .fill(.tint)
                        .frame(width: 7, height: 7)
                }
                Text(article.displayTitle)
                    .font(.callout)
                    .fontWeight(isRead ? .regular : .semibold)
                    .foregroundStyle(isRead ? .secondary : .primary)
                    .lineLimit(titleLines)
            }
            if let feedTitle {
                Text(feedTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }
}
