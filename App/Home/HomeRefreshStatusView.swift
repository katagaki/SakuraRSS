import SwiftUI
import Hanami

struct HomeRefreshStatusView: View {

    let state: ScopedRefreshState
    var onStop: (() -> Void)?
    @Environment(FeedManager.self) private var feedManager
    @State private var isShowingRefreshingFeedsPopover: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            FeedRefreshProgressDonut(
                progress: state.progress,
                size: 18,
                lineWidth: 2,
                isStopping: state.isStopping,
                showsStopIndicator: true
            )
            Text(progressText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .contentShape(.capsule)
        .compatibleGlassEffect(in: .capsule, interactive: true)
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        .animation(.smooth, value: state.completed)
        .accessibilityLabel(Text(String(localized: "Refresh.Stop", table: "Home")))
        .gesture(
            ExclusiveGesture(
                LongPressGesture().onEnded { _ in
                    isShowingRefreshingFeedsPopover = true
                },
                TapGesture().onEnded {
                    if !state.isStopping { onStop?() }
                }
            )
        )
        .popover(isPresented: $isShowingRefreshingFeedsPopover) {
            RefreshingFeedsPopoverView(
                refreshingFeedIDs: state.refreshingFeedIDs,
                pendingFeedIDs: state.pendingFeedIDs
            )
            .environment(feedManager)
            .presentationCompactAdaptation(.popover)
        }
        .onChange(of: state.hasActiveProgress) { _, isActive in
            if !isActive { isShowingRefreshingFeedsPopover = false }
        }
    }

    private var progressText: String {
        if state.isStopping {
            return String(localized: "Refresh.Stopping", table: "Home")
        }
        return String(
            localized: "Home.Refreshing \(state.completed) \(state.total)",
            table: "Home"
        )
    }
}
