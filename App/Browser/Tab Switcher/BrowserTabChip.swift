import EnhancedNavigation
import SwiftUI
import Hanami

/// One tab in the iPad and Mac tab strip.
struct BrowserTabChip: View {

    @Environment(FeedManager.self) private var feedManager
    let tab: BrowserTab
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                BrowserLocationLabel(
                    description: BrowserLocationDescription.describe(tab, feedManager: feedManager),
                    iconSize: 15,
                    titleFont: .caption.weight(isSelected ? .semibold : .regular),
                    showsSubtitle: false
                )
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Menu.CloseTab", table: "Browser"))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: 200)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .background {
            Capsule()
                .fill(isSelected ? AnyShapeStyle(.background.secondary) : AnyShapeStyle(.clear))
        }
    }
}

/// Compared on what the chip draws, not its actions: the strip hands in new
/// closures every pass, so every chip would redraw whenever any tab changed.
/// The actions only ever act on this chip's own tab.
extension BrowserTabChip: Equatable {
    static func == (lhs: BrowserTabChip, rhs: BrowserTabChip) -> Bool {
        lhs.tab.id == rhs.tab.id
            && lhs.tab.root == rhs.tab.root
            && lhs.tab.pageIdentity == rhs.tab.pageIdentity
            && lhs.isSelected == rhs.isSelected
    }
}
