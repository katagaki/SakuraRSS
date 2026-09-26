import EnhancedNavigation
import SwiftUI
import Hanami

struct BrowserTodayShortcutsGrid: View {

    @Environment(FeedManager.self) private var feedManager
    @Environment(BrowserTabStore.self) private var store

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)

    private var lists: [FeedList] {
        let base = feedManager.isFocusEffective
            ? feedManager.lists.filter { feedManager.isListInFocus($0) }
            : feedManager.lists
        return base.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(BrowserTodayShortcut.allCases) { shortcut in
                Button {
                    open(shortcut)
                } label: {
                    BrowserTodayShortcutCell(shortcut: shortcut)
                }
                .buttonStyle(.plain)
            }
            ForEach(lists) { list in
                Button {
                    store.navigate(to: .list(list.id))
                } label: {
                    FollowingListGridCell(list: list)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        store.openTab(at: .list(list.id), inBackground: true)
                    } label: {
                        Label(String(localized: "Menu.OpenInNewTab", table: "Browser"),
                              systemImage: "plus.square.on.square")
                    }
                }
            }
        }
        .animation(.smooth.speed(2.0), value: feedManager.lists)
    }

    private func open(_ shortcut: BrowserTodayShortcut) {
        switch shortcut {
        case .following: store.navigate(to: .feeds)
        case .allContent: store.navigate(to: .allContent)
        case .topics: store.navigate(to: .topics)
        case .bookmarks: store.push(BrowserBookmarksDestination())
        }
    }
}

struct BrowserTodayShortcutCell: View {

    let shortcut: BrowserTodayShortcut

    private let iconSize: CGFloat = 56
    private let iconCornerRadius: CGFloat = 12

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            Image(systemName: shortcut.symbolName)
                .font(.system(size: 24))
                .foregroundStyle(.tint)
                .frame(width: iconSize, height: iconSize)
                .compatibleGlassEffect(
                    in: RoundedRectangle(cornerRadius: iconCornerRadius),
                    clear: false
                )
                .contentShape(
                    .hoverEffect,
                    AnyShape(RoundedRectangle(cornerRadius: iconCornerRadius))
                )
                .hoverEffect(.highlight)

            Text(shortcut.title)
                .font(.caption)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
    }
}
