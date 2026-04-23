import SwiftUI

/// Forwards scroll phase/offset to `FeedManager` so mark-as-read can defer during fast scroll.
struct TrackScrollActivityModifier: ViewModifier {

    @Environment(FeedManager.self) private var feedManager

    func body(content: Content) -> some View {
        content
            .onScrollPhaseChange { _, newPhase in
                feedManager.updateScrollPhase(newPhase)
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
