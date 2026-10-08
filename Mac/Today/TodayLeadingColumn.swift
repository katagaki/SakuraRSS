import Hanami
import SwiftUI

struct TodayLeadingColumn: View {

    let feedManager: FeedManager
    let actions: TodayActions
    let revisions: WindowDataRevisions

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                TodayHeader(isCompact: true)
                TodayQuickAccessGrid(feedManager: feedManager, actions: actions)
                TodayRecentContentSection(feedManager: feedManager, actions: actions, revisions: revisions)
            }
            .padding(24)
        }
        .background(.ultraThinMaterial)
    }
}
