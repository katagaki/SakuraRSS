import SwiftUI
import Hanami

struct BrowserTodayShortcutCell: View {
    let title: String
    let symbolName: String
    var section: FeedSection?
    @State private var icon: UIImage?

    private let iconSize: CGFloat = 56
    private let iconCornerRadius: CGFloat = 12

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            shortcutIcon
                .contentShape(
                    .hoverEffect,
                    AnyShape(RoundedRectangle(cornerRadius: iconCornerRadius))
                )
                .hoverEffect(.highlight)

            Text(title)
                .font(.caption)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
        .task(id: section) {
            guard let section else { return }
            icon = await Iconography.shared.icon(for: section)
        }
    }

    @ViewBuilder
    private var shortcutIcon: some View {
        if let icon {
            Image(uiImage: icon)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .clipShape(RoundedRectangle(cornerRadius: iconCornerRadius))
        } else {
            Image(systemName: symbolName)
                .font(.system(size: 24))
                .foregroundStyle(.tint)
                .frame(width: iconSize, height: iconSize)
                .compatibleGlassEffect(
                    in: RoundedRectangle(cornerRadius: iconCornerRadius),
                    clear: false
                )
        }
    }
}
