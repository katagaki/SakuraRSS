import SwiftUI

/// Lists feeds that are currently being refreshed (with a leading progress
/// indicator) and feeds that are still queued (no indicator).
struct RefreshingFeedsPopoverView: View {

    let refreshingFeedIDs: Set<Int64>
    let pendingFeedIDs: [Int64]
    @Environment(FeedManager.self) private var feedManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if refreshingFeeds.isEmpty, pendingFeeds.isEmpty {
                    Text(String(localized: "Refresh.Popover.Empty", table: "Home"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(refreshingFeeds) { feed in
                        RefreshingFeedRow(title: feed.title, isActive: true)
                    }
                    ForEach(pendingFeeds) { feed in
                        RefreshingFeedRow(title: feed.title, isActive: false)
                    }
                }
            }
            .padding(12)
        }
        .frame(maxHeight: 250)
    }

    private var refreshingFeeds: [Feed] {
        refreshingFeedIDs
            .compactMap { feedManager.feedsByID[$0] }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private var pendingFeeds: [Feed] {
        pendingFeedIDs.compactMap { feedManager.feedsByID[$0] }
    }
}

private struct RefreshingFeedRow: View {

    let title: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                if isActive {
                    ProgressView()
                        .controlSize(.mini)
                }
            }
            .frame(width: 16, height: 16)
            Text(title)
                .font(.footnote)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(isActive ? .primary : .secondary)
            Spacer(minLength: 0)
        }
    }
}
