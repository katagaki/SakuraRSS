import SwiftUI
import Hanami

struct TodayQuickAccessReorderDropDelegate: DropDelegate {

    let targetItem: TodayQuickAccessItem
    @Binding var items: [TodayQuickAccessItem]
    @Binding var draggedItem: TodayQuickAccessItem?
    let onReorder: () -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedItem, draggedItem != targetItem,
              let sourceIndex = items.firstIndex(of: draggedItem),
              let targetIndex = items.firstIndex(of: targetItem) else { return }
        withAnimation(.smooth.speed(2.0)) {
            items.move(
                fromOffsets: IndexSet(integer: sourceIndex),
                toOffset: targetIndex > sourceIndex ? targetIndex + 1 : targetIndex
            )
        }
        onReorder()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }
}
