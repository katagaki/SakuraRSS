# EnhancedNavigation

Safari-style tabs for SwiftUI, each tab with its own `NavigationPath`.

- `TabNavigationStore<Root, Identity>`: tabs, selection, a live-tab LRU, back history, persistence and restoration down to the page each tab was left on, and the tab switcher's zoom state.
- `TabRoot`: what a tab is parked on, stored as a string token.
- `TabPageIdentity`: what a page reports about itself, since a `NavigationPath` cannot be read back. Its `pathToken` is how the page is pushed again after a relaunch.
- `LiveTabStack`: mounts the recently used tabs and hides the rest.
- `TabZoomContainer`, `.tabCardFrame(id:in:)`, `TabSnapshotView`, `TabSnapshotHeaderBlur`: a full-screen switcher that the page zooms down onto.
- `.interactivePopGesture(for:)`: keeps swipe back working with the navigation bar hidden.
- `.reorderableTab(id:in:)`, `PageSlot`, `OverlayPage`, `FrameClock`, `DisplayMetrics`.

```swift
let store = TabNavigationStore<Location, PageIdentity>.restored(
    configuration: TabStoreConfiguration(
        persistenceKeyPrefix: "Browser",
        snapshotDirectoryName: "TabSnapshots"
    )
)

LiveTabStack(store: store) { tab in
    NavigationStack(path: store.pathBinding(for: tab.id)) {
        RootView(root: tab.root)
    }
    .interactivePopGesture(for: store)
}
.task { store.loadPersistedSnapshots() }
```

Pages report themselves with `store.setPageIdentity(_:for:)`. Restore pushed pages with `restorePathIfNeeded(for:rebuilding:)`, which hands back each saved path token for the app to turn into a value again.
