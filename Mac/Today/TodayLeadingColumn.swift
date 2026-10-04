import Hanami
import SwiftUI

struct TodayLeadingColumn: View {

    let feedManager: FeedManager
    let actions: TodayActions

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                TodayHeader(isCompact: true)
                TodayShortcutsGrid(feedManager: feedManager, actions: actions)
                TodayRecentContentSection(feedManager: feedManager, actions: actions)
            }
            .padding(24)
        }
        .background(.ultraThinMaterial)
    }
}
