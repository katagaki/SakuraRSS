import SwiftUI

/// A small pie-shaped progress badge meant to be overlaid on the
/// bottom-right corner of a feed's favicon.  Displays nothing when
/// there is no active fetch for the given feed ID.
struct FaviconProgressBadge: View {

    let feedID: Int64
    var size: CGFloat = 12

    var body: some View {
        let tracker = FetchProgressTracker.shared
        if tracker.activeFetches[feedID] != nil {
            TimelineView(.periodic(from: .now, by: 0.1)) { context in
                let progress = tracker.progress(for: feedID, now: context.date) ?? 0
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.55))
                    Circle()
                        .strokeBorder(Color.white.opacity(0.9), lineWidth: 0.8)
                    PieSliceShape(progress: progress)
                        .fill(Color.white)
                        .padding(2)
                }
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.25), radius: 0.5, x: 0, y: 0.5)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

/// Filled pie slice starting at 12 o'clock and sweeping clockwise.
struct PieSliceShape: Shape {

    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let clamped = min(max(progress, 0), 1)
        guard clamped > 0 else { return path }
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * clamped),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}
