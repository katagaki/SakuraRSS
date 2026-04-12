import SwiftUI

/// A small pie-shaped badge meant to be overlaid on the bottom-right
/// corner of a feed's favicon.  Visualises the rate-limit cooldown for
/// X and Instagram profile refreshes: the pie fills from empty to full
/// as the 30-minute window elapses, and the badge disappears once the
/// feed is eligible to refresh again.
///
/// A `TimelineView` drives the pie on a periodic schedule so it
/// advances smoothly without relying on any external observation
/// mechanism.
struct FaviconProgressBadge: View {

    /// Last successful refresh date, or `nil` for feeds that have not
    /// yet been fetched.
    let lastFetched: Date?

    /// Duration of the cooldown window.  For X and Instagram profile
    /// feeds this is 30 minutes.
    let cooldown: TimeInterval

    var size: CGFloat = 12

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let progress = cooldownProgress(now: context.date) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.6))
                    Circle()
                        .strokeBorder(Color.white.opacity(0.9), lineWidth: 0.8)
                    PieSliceShape(progress: progress)
                        .fill(Color.white)
                        .padding(2)
                }
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.3), radius: 0.5, x: 0, y: 0.5)
            } else {
                Color.clear.frame(width: size, height: size)
            }
        }
    }

    /// Returns the completed fraction (0...1) of the cooldown window,
    /// or `nil` if the feed is already eligible to refresh (pie hidden).
    private func cooldownProgress(now: Date) -> Double? {
        guard let lastFetched, cooldown > 0 else { return nil }
        let elapsed = now.timeIntervalSince(lastFetched)
        guard elapsed >= 0, elapsed < cooldown else { return nil }
        return min(max(elapsed / cooldown, 0), 1)
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
