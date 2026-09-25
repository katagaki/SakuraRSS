import SwiftUI

/// Keeps the recent tabs mounted so switching back is instant, and hides the
/// ones that are not on screen rather than tearing their stacks down.
public struct LiveTabStack<Root: TabRoot, Identity: TabPageIdentity, Content: View>: View {

    private let store: TabNavigationStore<Root, Identity>
    private let content: (NavigationTab<Root, Identity>) -> Content

    /// `content` should read as little of the store as it can: anything it
    /// reads re-runs it, in every mounted tab.
    public init(
        store: TabNavigationStore<Root, Identity>,
        @ViewBuilder content: @escaping (NavigationTab<Root, Identity>) -> Content
    ) {
        self.store = store
        self.content = content
    }

    public var body: some View {
        ZStack {
            ForEach(store.tabs) { tab in
                if store.isLive(tab.id) {
                    let isSelected = tab.id == store.selectedTabID
                    content(tab)
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
