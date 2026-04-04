import SwiftUI

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
