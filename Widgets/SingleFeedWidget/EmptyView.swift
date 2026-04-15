import SwiftUI

func emptyView(iconSize: CGFloat, textSize: CGFloat) -> some View {
    VStack(spacing: iconSize > 30 ? 8 : 4) {
        Image(systemName: "newspaper")
            .font(.system(size: iconSize))
            .foregroundStyle(.secondary)
        Text(String(localized: "NoArticles", table: "Widget"))
            .font(.system(size: textSize))
            .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
