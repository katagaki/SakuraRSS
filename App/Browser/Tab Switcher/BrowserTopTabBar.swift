import EnhancedNavigation
import SwiftUI
import Hanami

/// The iPad and Mac tab strip, which replaces the compact tab switcher.
struct BrowserTopTabBar: View {

    @Environment(BrowserTabStore.self) private var store

    var body: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 4) {
                    ForEach(store.tabs) { tab in
                        BrowserTabChip(
                            tab: tab,
                            isSelected: tab.id == store.selectedTabID,
                            onSelect: { store.select(tab.id) },
                            onClose: {
                                withAnimation(.smooth.speed(1.5)) {
                                    store.close(tab.id)
                                }
                            }
                        )
                        .equatable()
                        .reorderableTab(id: tab.id, in: store)
                    }
                }
                .padding(.horizontal, 4)
            }
            .scrollIndicators(.hidden)

            Button {
                store.openTab()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Menu.NewTab", table: "Browser"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}
