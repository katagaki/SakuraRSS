import SwiftUI
import Hanami

struct BrowserTodayShortcutsGrid: View {

    @Environment(BrowserTabStore.self) private var store

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)

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
        }
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
