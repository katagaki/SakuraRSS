import SwiftUI
import Hanami

/// Safari's tab grid.
struct BrowserTabSwitcher: View {

    /// Long enough for the scale to read; the default speed pops.
    static let transitionDuration: Double = 0.34

    static let transitionAnimation: Animation = .smooth(duration: transitionDuration)

    @Environment(BrowserTabStore.self) private var store
    @Environment(FeedManager.self) private var feedManager
    @State private var isShowingProfile = false

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
            .sheet(isPresented: $isShowingProfile) {
                ProfileView(titleDisplayMode: .inline)
                    .environment(feedManager)
            }
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
                // A tick late, so the new tab's card has reported the rect the
                // page grows from.
                Task { @MainActor in dismissSwitcher() }
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel(String(localized: "Menu.NewTab", table: "Browser"))
        }
        ToolbarItem(placement: .bottomBar) {
            Button {
                isShowingProfile = true
            } label: {
                Image(systemName: "person.crop.circle")
            }
            .accessibilityLabel(String(localized: "Tabs.Profile"))
        }

        #if !os(visionOS)
        ToolbarSpacer(.flexible, placement: .bottomBar)
        #endif

        ToolbarItem(placement: .bottomBar) {
            Button(role: .confirm) {
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
        store.hideTabSwitcher()
    }
}
