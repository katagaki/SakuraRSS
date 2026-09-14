import SwiftUI
import Hanami

/// Safari's tab grid. Cards render a cheap preview rather than a live snapshot,
/// because only a handful of tabs are kept alive at a time.
struct BrowserTabSwitcher: View {

    @Environment(BrowserTabStore.self) private var store

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(store.tabs) { tab in
                        BrowserTabCard(
                            tab: tab,
                            isSelected: tab.id == store.selectedTabID,
                            onSelect: { select(tab.id) },
                            onClose: { close(tab.id) }
                        )
                    }
                }
                .padding(16)
            }
            .navigationTitle(String(localized: "Tabs.Count \(store.tabs.count)", table: "Browser"))
            .toolbarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sakuraBackground()
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Button(role: .destructive) {
                    withAnimation(.smooth.speed(1.5)) {
                        store.closeAll()
                    }
                } label: {
                    Label(String(localized: "Tabs.CloseAll", table: "Browser"),
                          systemImage: "xmark.square.fill")
                }
            } label: {
                Image(systemName: "ellipsis")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                store.openTab()
                dismissSwitcher()
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel(String(localized: "Menu.NewTab", table: "Browser"))
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(String(localized: "Tabs.Done", table: "Browser")) {
                dismissSwitcher()
            }
        }
    }

    private func select(_ tabID: UUID) {
        store.select(tabID)
        dismissSwitcher()
    }

    private func close(_ tabID: UUID) {
        withAnimation(.smooth.speed(1.5)) {
            store.close(tabID)
        }
    }

    private func dismissSwitcher() {
        withAnimation(.smooth.speed(1.5)) {
            store.isShowingTabSwitcher = false
        }
    }
}
