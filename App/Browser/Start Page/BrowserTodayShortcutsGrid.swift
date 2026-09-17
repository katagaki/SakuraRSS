import SwiftUI
import Hanami

struct BrowserTodayShortcutsGrid: View {

    @Environment(BrowserTabStore.self) private var store

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
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

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: shortcut.symbolName)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(height: 26)

            Text(shortcut.title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.quinary, in: .rect(cornerRadius: 14))
        .contentShape(.rect(cornerRadius: 14))
        .hoverEffect(.highlight)
    }
}
