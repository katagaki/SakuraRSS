import SwiftUI
import UniformTypeIdentifiers
import Hanami

struct BrowserTodayQuickAccessEditingGrid: View {

    @Environment(FeedManager.self) private var feedManager
    @State private var items: [TodayQuickAccessItem] = []
    @State private var draggedItem: TodayQuickAccessItem?

    private let preferences = TodayQuickAccessPreferences.shared

    /// The icon's centre, measured from the badge, so the badge swings with the icon.
    private static let badgeRotationAnchor = UnitPoint(x: 0.5 + 26.0 / 24.0, y: 0.5 + 26.0 / 24.0)

    var body: some View {
        LazyVGrid(columns: BrowserTodayQuickAccessGrid.columns, spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.element) { index, item in
                cell(for: item, at: index)
            }
        }
        .onAppear {
            items = preferences.ordered(TodayQuickAccessItem.browserItems(in: feedManager))
        }
    }

    private func cell(for item: TodayQuickAccessItem, at index: Int) -> some View {
        let isHidden = preferences.isHidden(item)
        return BrowserTodayQuickAccessLabel(item: item, isEditing: true)
            .opacity(isHidden ? 0.4 : 1)
            .overlay(alignment: .top) {
                TodayQuickAccessVisibilityBadge(isVisible: !isHidden)
                    .wiggleRotation(anchor: Self.badgeRotationAnchor)
                    .offset(x: -26, y: -10)
            }
            .wiggleChildren(true, seed: Double(index % 17) / 17.0)
            .contentShape(.rect)
            .onTapGesture {
                withAnimation(.smooth.speed(2.0)) {
                    preferences.setHidden(!isHidden, for: item)
                }
            }
            .onDrag {
                draggedItem = item
                return NSItemProvider(object: item.id as NSString)
            }
            .onDrop(
                of: [.text],
                delegate: TodayQuickAccessReorderDropDelegate(
                    targetItem: item,
                    items: $items,
                    draggedItem: $draggedItem,
                    onReorder: { preferences.saveOrder(items) }
                )
            )
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(isHidden ? .isButton : [.isButton, .isSelected])
    }
}
