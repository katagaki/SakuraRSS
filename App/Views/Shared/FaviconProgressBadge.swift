import SwiftUI

/// Full-icon overlay that visualises a feed's rate-limit cooldown.
/// Dims the underlying favicon and fills clockwise as the cooldown elapses.
struct FaviconProgressBadge: View {

    let lastFetched: Date?
    let cooldown: TimeInterval

    var size: CGFloat = 56
    var isCircle: Bool = true
    var cornerRadius: CGFloat = 12

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let progress = cooldownProgress(now: context.date) {
                ZStack {
                    shape
                        .fill(Color.clear)
                    PieSliceShape(progress: 1 - progress)
                        .fill(Color.black.opacity(0.4))
                        .clipShape(shape)
                }
                .frame(width: size, height: size)
                .allowsHitTesting(false)
            } else {
                Color.clear.frame(width: size, height: size)
            }
        }
    }

    private var shape: AnyShape {
        if isCircle {
            AnyShape(Circle())
        } else {
            AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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
        let radius = max(rect.width, rect.height)
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
