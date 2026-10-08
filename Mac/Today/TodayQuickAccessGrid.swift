import Hanami
import SwiftUI

struct TodayQuickAccessGrid: View {

    let feedManager: FeedManager
    let actions: TodayActions

    private let preferences = TodayQuickAccessPreferences.shared
    private let columns = [GridItem(.adaptive(minimum: 76), spacing: 12)]

    private var visibleLocations: [(item: TodayQuickAccessItem, location: BrowserLocation)] {
        preferences.visible(TodayQuickAccessItem.macItems(in: feedManager)).compactMap { item in
            item.location.map { (item, $0) }
        }
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(visibleLocations, id: \.item) { item, location in
                tile(item, location: location)
            }
        }
    }

    private func tile(_ item: TodayQuickAccessItem, location: BrowserLocation) -> some View {
        Button {
            actions.open(location)
        } label: {
            TodayQuickAccessTile(
                title: location.title(in: feedManager),
                symbolName: location.symbolName(in: feedManager),
                section: section(of: item)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            TodayOpenInNewTabButton(location: location, actions: actions)
            Divider()
            Button(String(localized: "Today.QuickAccess.Hide", table: "Home")) {
                preferences.setHidden(true, for: item)
            }
            Button(String(localized: "Today.QuickAccess.Edit", table: "Home") + "…") {
                actions.editQuickAccess()
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func section(of item: TodayQuickAccessItem) -> FeedSection? {
        if case .feedSection(let section) = item {
            return section
        }
        return nil
    }
}
