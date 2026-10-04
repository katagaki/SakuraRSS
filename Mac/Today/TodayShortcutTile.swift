import Hanami
import SwiftUI

struct TodayShortcutTile: View {

    let title: String
    let symbolName: String
    var section: FeedSection?
    @State private var icon: NSImage?
    @State private var isHovering = false

    private let iconSize: CGFloat = 52
    private let cornerRadius: CGFloat = 12

    var body: some View {
        VStack(spacing: 6) {
            iconView
                .frame(width: iconSize, height: iconSize)
                .clipShape(.rect(cornerRadius: cornerRadius))
                .brightness(isHovering ? 0.08 : 0)
            Text(title)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
        }
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
        .onHover { isHovering = $0 }
        .task(id: section) {
            guard let section else { return }
            icon = await Iconography.shared.icon(for: section)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let icon {
            Image(nsImage: icon)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: symbolName)
                .font(.system(size: 22))
                .foregroundStyle(.tint)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.quinary)
        }
    }
}
