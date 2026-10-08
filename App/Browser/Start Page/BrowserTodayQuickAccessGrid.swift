import EnhancedNavigation
import SwiftUI
import Hanami

struct BrowserTodayQuickAccessGrid: View {

    @Environment(FeedManager.self) private var feedManager
    @Environment(BrowserTabStore.self) private var store
    var isEditing: Bool
    var onBeginEditing: () -> Void

    static let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)

    private let preferences = TodayQuickAccessPreferences.shared

    private var visibleItems: [TodayQuickAccessItem] {
        preferences.visible(TodayQuickAccessItem.browserItems(in: feedManager))
    }

    var body: some View {
        if isEditing {
            BrowserTodayQuickAccessEditingGrid()
        } else {
            quickAccessGrid
        }
    }

    private var quickAccessGrid: some View {
        LazyVGrid(columns: Self.columns, spacing: 12) {
            ForEach(visibleItems) { item in
                Button {
                    open(item)
                } label: {
                    BrowserTodayQuickAccessLabel(item: item)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    if let location = item.browserLocation {
                        openInNewTabButton(location)
                    }
                    Button {
                        withAnimation(.smooth.speed(2.0)) {
                            preferences.setHidden(true, for: item)
                        }
                    } label: {
                        Label(String(localized: "Today.QuickAccess.Hide", table: "Home"),
                              systemImage: "eye.slash")
                    }
                    Button(action: onBeginEditing) {
                        Label(String(localized: "Today.QuickAccess.Edit", table: "Home"),
                              systemImage: "square.grid.2x2")
                    }
                }
            }
        }
        .animation(.smooth.speed(2.0), value: visibleItems)
        .animation(.smooth.speed(2.0), value: feedManager.lists)
    }

    private func openInNewTabButton(_ location: BrowserLocation) -> some View {
        Button {
            store.openTab(at: location, inBackground: true)
        } label: {
            Label(String(localized: "Menu.OpenInNewTab", table: "Browser"),
                  systemImage: "plus.square.on.square")
        }
    }

    private func open(_ item: TodayQuickAccessItem) {
        if let location = item.browserLocation {
            store.navigate(to: location)
        } else {
            store.push(BrowserBookmarksDestination())
        }
    }
}
