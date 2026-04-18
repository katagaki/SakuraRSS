import SwiftUI

/// A small donut-shaped progress indicator displayed in the Home tab
/// toolbar while feeds are refreshing.  The ring fills from empty to
/// full as each individual feed finishes loading.
struct FeedRefreshProgressDonut: View {

    let progress: Double
    var size: CGFloat = 18
    var lineWidth: CGFloat = 2.5

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.25), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.smooth, value: clampedProgress)
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(Text(String(localized: "Refresh.Progress", table: "Home")))
        .accessibilityValue(
            Text(clampedProgress, format: .percent.precision(.fractionLength(0)))
        )
    }
}
