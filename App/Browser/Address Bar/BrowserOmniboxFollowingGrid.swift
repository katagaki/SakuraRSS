import SwiftUI
import Hanami

/// The Following grid, shown in place of suggestions before anything is typed.
/// Drawn without a background so the dimmed page shows through, the way the
/// suggestion rows do.
struct BrowserOmniboxFollowingGrid: View {

    @Environment(FeedManager.self) private var feedManager

    let openFeed: (Feed) -> Void
    let openSection: (FeedSection) -> Void

    private let gridColumns = [GridItem(.adaptive(minimum: 80), spacing: 16)]

    private var feeds: [Feed] {
        guard feedManager.isFocusEffective else { return feedManager.feeds }
        let focused = feedManager.focusedFeedIDs
        return feedManager.feeds.filter { focused.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                let groupedFeeds = feeds.groupedByFeedSection()
                ForEach(FeedSection.allCases, id: \.self) { section in
                    if let sectionFeeds = groupedFeeds[section], !sectionFeeds.isEmpty {
                        sectionGrid(section, feeds: sectionFeeds)
                    }
                }
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .compatibleInteractiveKeyboardDismissal()
    }

    private func sectionGrid(_ section: FeedSection, feeds: [Feed]) -> some View {
        Section {
            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 12) {
                ForEach(feeds) { feed in
                    Button {
                        openFeed(feed)
                    } label: {
                        FollowingFeedGridCell(feed: feed)
                    }
                    .buttonStyle(.plain)
                    .id(feed.id)
                }
            }
        } header: {
            Button {
                openSection(section)
            } label: {
                FollowingSectionHeaderLabel(section: section)
            }
            .buttonStyle(.plain)
        }
    }
}
