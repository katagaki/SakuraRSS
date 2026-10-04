import Hanami
import SwiftUI

/// What the address bar's popup shows before anything is typed, as iOS's
/// omnibox does: every followed feed, grouped by type.
struct AddressFollowingGrid: View {

    let feedManager: FeedManager
    let onOpen: (BrowserLocation) -> Void

    private let columns = [GridItem(.adaptive(minimum: 76), spacing: 12)]

    private var feeds: [Feed] {
        guard feedManager.isFocusEffective else { return feedManager.feeds }
        let focusedIDs = feedManager.focusedFeedIDs
        return feedManager.feeds.filter { focusedIDs.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            let feeds = feeds
            ForEach(FeedSection.allCases, id: \.self) { section in
                let sectionFeeds = feeds
                    .filter { $0.feedSection == section }
                    .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
                if !sectionFeeds.isEmpty {
                    sectionGrid(section, feeds: sectionFeeds)
                }
            }
        }
        .padding(16)
    }

    private func sectionGrid(_ section: FeedSection, feeds: [Feed]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                onOpen(.feedSection(section))
            } label: {
                HStack(spacing: 4) {
                    Text(section.localizedTitle)
                        .font(.headline)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(feeds) { feed in
                    Button {
                        onOpen(.feed(feed.id))
                    } label: {
                        AddressFollowingFeedCell(feed: feed)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
        }
    }
}
