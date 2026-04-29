import SwiftUI

/// Flushes queued mark-as-read IDs when scrolling goes idle.
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
    }
}

extension View {
    func trackScrollActivity() -> some View {
        modifier(TrackScrollActivityModifier())
    }
}
