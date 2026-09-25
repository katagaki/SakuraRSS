import EnhancedNavigation
import SwiftUI

struct BrowserTabStack: View {

    @Environment(BrowserTabStore.self) private var store
    @Environment(BrowserPageSlots.self) private var slots

    var body: some View {
        LiveTabStack(store: store) { tab in
            BrowserTabContentView(store: store, slots: slots, tabID: tab.id, location: tab.root)
        }
    }
}
