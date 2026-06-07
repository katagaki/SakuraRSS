import SwiftUI
import Hanami

struct HomeRefreshStatusStrip: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(TodayManager.self) var todayManager
    @AppStorage("Intelligence.ContentInsights.Enabled") private var contentInsightsEnabled: Bool = false
    let selectionStore: HomeSelectionStore
    let usesPhoneTopBarRedesign: Bool

    private var refreshState: ScopedRefreshState {
        HomeRefreshScope.state(feedManager: feedManager, selection: selectionStore.selection)
    }

    var body: some View {
        if usesPhoneTopBarRedesign {
            ZStack {
                if refreshState.hasActiveProgress {
                    HomeRefreshStatusView(
                        state: refreshState,
                        onStop: cancelRefresh
                    )
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.smooth, value: refreshState.hasActiveProgress)
        }
    }

    private func cancelRefresh() {
        HomeRefreshScope.cancel(
            feedManager: feedManager,
            todayManager: todayManager,
            selection: selectionStore.selection,
            loadEntities: contentInsightsEnabled
        )
    }
}
