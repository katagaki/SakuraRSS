import SwiftUI

/// How far through the episode or video playback is, as a ring that fills
/// with the elapsed share of the total time.
struct PlaybackProgressDonut: View {

    let isPlaying: Bool
    let elapsedFraction: () -> Double

    var body: some View {
        TimelineView(.periodic(from: .now, by: isPlaying ? 1 : 60)) { _ in
            let fraction = min(max(elapsedFraction(), 0), 1)
            ZStack {
                Circle()
                    .stroke(.tertiary, lineWidth: 2.5)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(.tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .padding(1.25)
            .animation(.linear(duration: 0.3), value: fraction)
        }
    }
}
