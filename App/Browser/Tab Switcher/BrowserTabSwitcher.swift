import EnhancedNavigation
import SwiftUI
import Hanami

/// Safari's tab grid.
struct BrowserTabSwitcher: View {

    @Environment(BrowserTabStore.self) private var store
    @Environment(FeedManager.self) private var feedManager
    @State private var isShowingProfile = false
    @State private var isDismissing = false

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
                        .equatable()
                        .reorderableTab(id: tab.id, in: store)
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
            .background(Color(uiColor: .secondarySystemGroupedBackground).ignoresSafeArea())
        }
        // The grid stays mounted for the whole session, so this runs once,
        // early, and every tab is rebuilt long before one is tapped.
        .task { await store.prewarmRestorablePaths(in: feedManager) }
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
                guard !isDismissing else { return }
                store.openTab()
                // Once drawn, so the new tab's card has reported the rect the
                // page grows from and its stack is mounted before the growth.
                dismissSwitcherOnceSettled()
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
        guard !isDismissing else { return }
        // Normally already done by the prewarm; here for the tab tapped
        // before it got its turn, so the rebuild still happens before the
        // growth rather than in the middle of it.
        store.restorePathIfNeeded(for: tabID, in: feedManager)
        store.select(tabID)
        // Selecting a tab mounts its stack if it is not live, and hands the
        // bottom bar over either way. A tick late was not enough: that work
        // is drawn in the next frame, which was the growth's first, and the
        // page froze on the card before it moved. Behind the grid it is free.
        dismissSwitcherOnceSettled()
    }

    private func dismissSwitcherOnceSettled() {
        isDismissing = true
        Task { @MainActor in
            await FrameClock.waitForSettledFrames()
            dismissSwitcher()
            isDismissing = false
        }
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
