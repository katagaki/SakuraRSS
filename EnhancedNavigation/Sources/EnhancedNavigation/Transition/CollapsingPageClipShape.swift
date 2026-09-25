import SwiftUI

/// Clips a page as it collapses onto a card. A shape rather than a frame:
/// animating a frame re-lays the page out on every tick.
nonisolated struct CollapsingPageClipShape: Shape {

    /// Where the window leaves the page's proportions for the card's. Cropping
    /// any earlier parks the bottom edge and leaves the top one sliding down
    /// alone, which reads as a slide rather than a zoom.
    private static let tuckingStart: CGFloat = 0.85

    var progress: CGFloat
    let expanded: CGRect
    let collapsed: CGRect
    let expandedRadius: CGFloat
    let collapsedRadius: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in bounds: CGRect) -> Path {
        let zoom = min(max(progress, 0), 1)
        let width = interpolate(expanded.width, collapsed.width, zoom)
        let rect = CGRect(
            x: interpolate(expanded.minX, collapsed.minX, zoom),
            y: interpolate(expanded.minY, collapsed.minY, zoom),
            width: width,
            height: height(atWidth: width, zoom: zoom)
        )
        return Path(
            roundedRect: rect,
            cornerRadius: interpolate(expandedRadius, collapsedRadius, zoom),
            style: .continuous
        )
    }

    /// The page's proportions for most of the way, the card's by the end.
    private func height(atWidth width: CGFloat, zoom: CGFloat) -> CGFloat {
        guard expanded.width > 0, collapsed.width > 0 else { return expanded.height }
        let start = CollapsingPageClipShape.tuckingStart
        let tucking = min(max((zoom - start) / (1 - start), 0), 1)
        return interpolate(
            expanded.height * width / expanded.width,
            collapsed.height * width / collapsed.width,
            tucking * tucking * (3 - 2 * tucking)
        )
    }

    private func interpolate(_ start: CGFloat, _ end: CGFloat, _ amount: CGFloat) -> CGFloat {
        start + (end - start) * amount
    }
}
