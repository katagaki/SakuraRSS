import SwiftUI

/// Keeps the recent tabs mounted so switching back is instant, and hides the
/// ones that are not on screen rather than tearing their stacks down.
struct BrowserTabStack: View {

    @Environment(BrowserTabStore.self) private var store

    var body: some View {
        ZStack {
            ForEach(store.tabs) { tab in
                if store.isLive(tab.id) {
                    let isSelected = tab.id == store.selectedTabID
                    BrowserTabContentView(store: store, tabID: tab.id)
                        .opacity(isSelected ? 1 : 0)
                        .allowsHitTesting(isSelected)
                        // A zero-opacity tab still publishes its accessibility
                        // elements, so assistive tech would read every mounted
                        // tab at once. Collapsing the subtree is what actually
                        // takes them out of the tree.
                        .accessibilityElement(children: isSelected ? .contain : .ignore)
                        .accessibilityHidden(!isSelected)
                }
            }
        }
    }
}
