import SwiftUI

/// Pie badge overlaid on a favicon to visualise rate-limit cooldown progress.
struct FaviconProgressBadge: View {

    let lastFetched: Date?
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

    /// Returns 0...1 cooldown fraction, or `nil` if refresh is already eligible.
    private func cooldownProgress(now: Date) -> Double? {
        guard let lastFetched, cooldown > 0 else { return nil }
        let elapsed = now.timeIntervalSince(lastFetched)
        guard elapsed >= 0, elapsed < cooldown else { return nil }
        return min(max(elapsed / cooldown, 0), 1)
    }
}

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
