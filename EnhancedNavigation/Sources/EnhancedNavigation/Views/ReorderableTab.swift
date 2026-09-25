import SwiftUI

public extension View {
    /// Lets tabs be dragged onto one another to reorder them.
    func reorderableTab<Root, Identity>(
        id tabID: UUID,
        in store: TabNavigationStore<Root, Identity>,
        animation: Animation = .smooth
    ) -> some View {
        draggable(tabID.uuidString)
            .dropDestination(for: String.self) { identifiers, _ in
                guard let identifier = identifiers.first,
                      let draggedTabID = UUID(uuidString: identifier),
                      store.tabs.contains(where: { $0.id == draggedTabID }) else { return false }
                withAnimation(animation) {
                    store.moveTab(draggedTabID, to: tabID)
                }
                return true
            }
    }
}
