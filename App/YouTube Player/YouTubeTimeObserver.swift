import SwiftUI
import Hanami

/// Observes a time source and runs a callback when it changes, scoped to its
/// own view body so the parent does not invalidate on every periodic tick.
/// The closure form is required: passing an already-read `TimeInterval` from
/// the parent would force the parent's body to re-evaluate whenever time
/// changes, defeating the purpose. The read must happen inside this view.
struct YouTubeTimeObserver: View {

    let currentTime: () -> TimeInterval
    let onTimeChange: (TimeInterval) -> Void

    var body: some View {
        let time = currentTime()
        return Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onChange(of: time) { _, newTime in
                onTimeChange(newTime)
            }
    }
}
