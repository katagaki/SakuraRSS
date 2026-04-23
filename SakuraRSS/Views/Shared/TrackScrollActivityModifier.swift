import SwiftUI

/// Forwards scroll phase/offset to `FeedManager`, and flushes queued
/// mark-as-read IDs when scrolling goes idle so the resulting re-render
/// doesn't land in the middle of a flick.
struct TrackScrollActivityModifier: ViewModifier {

    @Environment(FeedManager.self) private var feedManager

    func body(content: Content) -> some View {
        content
            .onScrollPhaseChange { _, newPhase in
                feedManager.updateScrollPhase(newPhase)
                if newPhase == .idle {
                    feedManager.flushDebouncedReads()
                }
            }
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { _, newOffset in
                feedManager.updateScrollOffset(newOffset)
            }
    }
}

extension View {
    func trackScrollActivity() -> some View {
        modifier(TrackScrollActivityModifier())
    }
}
