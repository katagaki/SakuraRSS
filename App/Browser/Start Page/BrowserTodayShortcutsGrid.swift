import EnhancedNavigation
import SwiftUI
import Hanami

struct BrowserTodayShortcutsGrid: View {

    @Environment(FeedManager.self) private var feedManager
    @Environment(BrowserTabStore.self) private var store
    var onEditShortcuts: () -> Void

    private let preferences = TodayShortcutPreferences.shared
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)

    private var visibleItems: [TodayShortcutItem] {
        preferences.visible(TodayShortcutItem.browserItems(in: feedManager))
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(visibleItems) { item in
                Button {
                    open(item)
                } label: {
                    label(for: item)
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
                        Label(String(localized: "Today.Shortcuts.Hide", table: "Home"),
                              systemImage: "eye.slash")
                    }
                    Button(action: onEditShortcuts) {
                        Label(String(localized: "Today.Shortcuts.Edit", table: "Home"),
                              systemImage: "square.grid.2x2")
                    }
                }
            }
        }
        .animation(.smooth.speed(2.0), value: visibleItems)
        .animation(.smooth.speed(2.0), value: feedManager.lists)
    }

    @ViewBuilder
    private func label(for item: TodayShortcutItem) -> some View {
        switch item {
        case .list(let listID):
            if let list = feedManager.lists.first(where: { $0.id == listID }) {
                FollowingListGridCell(list: list)
            }
        case .feedSection(let section):
            BrowserTodayShortcutCell(
                title: item.browserTitle(in: feedManager),
                symbolName: item.browserSymbolName(in: feedManager),
                section: section
            )
        default:
            BrowserTodayShortcutCell(
                title: item.browserTitle(in: feedManager),
                symbolName: item.browserSymbolName(in: feedManager)
            )
        }
    }

    private func openInNewTabButton(_ location: BrowserLocation) -> some View {
        Button {
            store.openTab(at: location, inBackground: true)
        } label: {
            Label(String(localized: "Menu.OpenInNewTab", table: "Browser"),
                  systemImage: "plus.square.on.square")
        }
    }

    private func open(_ item: TodayShortcutItem) {
        if let location = item.browserLocation {
            store.navigate(to: location)
        } else {
            store.push(BrowserBookmarksDestination())
        }
    }
}
