import SwiftUI
import Hanami

struct BrowserTodayQuickAccessCell: View {
    let title: String
    let symbolName: String
    var section: FeedSection?
    @State private var icon: UIImage?

    private let iconSize: CGFloat = 56
    private let iconCornerRadius: CGFloat = 12

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            itemIcon
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
                .wiggleRotation()
        }
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
        .task(id: section) {
            guard let section else { return }
            icon = await Iconography.shared.icon(for: section)
        }
    }

    @ViewBuilder
    private var itemIcon: some View {
        if let icon {
            Image(uiImage: icon)
                .resizable()
                .scaledToFill()
                .frame(width: iconSize, height: iconSize)
                .clipShape(RoundedRectangle(cornerRadius: iconCornerRadius))
                .wiggleRotation()
        } else {
            Image(systemName: symbolName)
                .font(.system(size: 24))
                .foregroundStyle(.tint)
                .wiggleRotation()
                .frame(width: iconSize, height: iconSize)
                .wiggleGlassEffect(in: RoundedRectangle(cornerRadius: iconCornerRadius))
        }
    }
}
