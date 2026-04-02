import SwiftUI

struct FeedTitleLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .center)
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
