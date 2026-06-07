import SwiftUI
import Hanami

struct HomeRefreshStatusView: View {

    let state: ScopedRefreshState
    var onStop: (() -> Void)?
    @Binding var isShowingDetails: Bool
    let refreshingFeedIDs: Set<Int64>
    let pendingFeedIDs: [Int64]
    @Environment(FeedManager.self) private var feedManager

    var body: some View {
        Button {
            onStop?()
        } label: {
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
        }
        .buttonStyle(.plain)
        .disabled(state.isStopping)
        .compatibleGlassEffect(in: .capsule, interactive: true)
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        .animation(.smooth, value: state.completed)
        .accessibilityLabel(Text(String(localized: "Refresh.Stop", table: "Home")))
        .onLongPressGesture {
            isShowingDetails = true
        }
        .popover(isPresented: $isShowingDetails) {
            RefreshingFeedsPopoverView(
                refreshingFeedIDs: refreshingFeedIDs,
                pendingFeedIDs: pendingFeedIDs
            )
            .environment(feedManager)
            .presentationCompactAdaptation(.popover)
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
