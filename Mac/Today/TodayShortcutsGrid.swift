import Hanami
import SwiftUI

struct TodayShortcutsGrid: View {

    let feedManager: FeedManager
    let actions: TodayActions

    private let columns = [GridItem(.adaptive(minimum: 76), spacing: 12)]

    private var feedSections: [FeedSection] {
        let followed = Set(feedManager.feeds.map(\.feedSection))
        return FeedSection.allCases.filter { followed.contains($0) }
    }

    private var lists: [FeedList] {
        feedManager.lists.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(feedSections, id: \.self) { section in
                tile(.feedSection(section), section: section)
            }
            tile(.allContent)
            tile(.bookmarks)
            ForEach(lists) { list in
                tile(.list(list.id))
            }
        }
    }

    private func tile(_ location: BrowserLocation, section: FeedSection? = nil) -> some View {
        Button {
            actions.open(location)
        } label: {
            TodayShortcutTile(
                title: location.title(in: feedManager),
                symbolName: location.symbolName(in: feedManager),
                section: section
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            TodayOpenInNewTabButton(location: location, actions: actions)
        }
    }
}
