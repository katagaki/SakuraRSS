import AppIntents
import SwiftUI

struct FeedTitleBar: View {
    let title: String
    let feedID: Int64
    let currentPage: Int
    let totalPages: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            if totalPages > 1 {
                HStack(spacing: 12) {
                    Button(intent: SingleFeedPageIntent(feedID: feedID, page: currentPage - 1)) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(currentPage > 0 ? .primary : .quaternary)
                    }
                    .disabled(currentPage <= 0)

                    Text("\(currentPage + 1)/\(totalPages)")
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)

                    Button(intent: SingleFeedPageIntent(feedID: feedID, page: currentPage + 1)) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(currentPage < totalPages - 1 ? .primary : .quaternary)
                    }
                    .disabled(currentPage >= totalPages - 1)
                }
            }
        }
    }
}

func emptyView(iconSize: CGFloat, textSize: CGFloat) -> some View {
    VStack(spacing: iconSize > 30 ? 8 : 4) {
        Image(systemName: "newspaper")
            .font(.system(size: iconSize))
            .foregroundStyle(.secondary)
        Text("Widget.NoArticles")
            .font(.system(size: textSize))
            .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
