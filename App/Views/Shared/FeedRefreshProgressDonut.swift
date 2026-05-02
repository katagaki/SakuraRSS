import SwiftUI

/// Donut progress indicator shown in the Home toolbar during feed refresh.
struct FeedRefreshProgressDonut: View {

    let progress: Double
    var size: CGFloat = 22
    var lineWidth: CGFloat = 2
    var onStop: (() -> Void)?

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        if let onStop {
            Button(action: onStop) {
                donut
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityLabel(
                Text(String(localized: "Refresh.Stop", table: "Home"))
            )
            .accessibilityValue(
                Text(clampedProgress, format: .percent.precision(.fractionLength(0)))
            )
        } else {
            donut
                .accessibilityElement()
                .accessibilityLabel(
                    Text(String(localized: "Refresh.Progress", table: "Home"))
                )
                .accessibilityValue(
                    Text(clampedProgress, format: .percent.precision(.fractionLength(0)))
                )
        }
    }

    private var donut: some View {
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
            if onStop != nil {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.accentColor)
                    .frame(width: size * 0.32, height: size * 0.32)
            }
        }
        .frame(width: size, height: size)
        .padding(lineWidth / 2)
    }
}
