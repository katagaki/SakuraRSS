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

    private var feedSections: [FeedSection] {
        let feeds = feedManager.isFocusEffective
            ? feedManager.feeds.filter { feedManager.focusedFeedIDs.contains($0.id) }
            : feedManager.feeds
        let followedSections = Set(feeds.map(\.feedSection))
        return FeedSection.allCases.filter { followedSections.contains($0) }
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(feedSections, id: \.self) { section in
                Button {
                    store.navigate(to: .feedSection(section))
                } label: {
                    BrowserTodayShortcutCell(
                        title: section.localizedTitle,
                        symbolName: section.browserSymbolName
                    )
                }
                .buttonStyle(.plain)
                .contextMenu {
                    openInNewTabButton(.feedSection(section))
                }
            }
            ForEach(BrowserTodayShortcut.allCases) { shortcut in
                Button {
                    open(shortcut)
                } label: {
                    BrowserTodayShortcutCell(title: shortcut.title, symbolName: shortcut.symbolName)
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
                    openInNewTabButton(.list(list.id))
                }
            }
        }
        .animation(.smooth.speed(2.0), value: feedSections)
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

    private func open(_ shortcut: BrowserTodayShortcut) {
        switch shortcut {
        case .allContent: store.navigate(to: .allContent)
        case .topics: store.navigate(to: .topics)
        case .bookmarks: store.push(BrowserBookmarksDestination())
        }
    }
}

struct BrowserTodayShortcutCell: View {

    let title: String
    let symbolName: String

    private let iconSize: CGFloat = 56
    private let iconCornerRadius: CGFloat = 12

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            Image(systemName: symbolName)
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

            Text(title)
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
