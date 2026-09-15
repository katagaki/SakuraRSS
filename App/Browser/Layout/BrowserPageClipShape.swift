import SwiftUI

/// Clips the page to the card's rect while it collapses. A shape rather than a
/// frame so the crop costs nothing but a mask: animating the frame would re-lay
/// the page out on every tick.
nonisolated struct BrowserPageClipShape: Shape {

    /// Where the window stops matching the page's proportions and tucks in to
    /// the card's. Until then it is a plain zoom, every edge closing in at a
    /// rate proportional to how far it has to go; cropping any earlier leaves
    /// the bottom edge parked and the top edge sliding down on its own.
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

    /// The page's own proportions for most of the way, the card's by the end.
    /// The tuck is left until the page is small and already dissolving into the
    /// snapshot, so the bottom edge never has to outrun the other three.
    private func height(atWidth width: CGFloat, zoom: CGFloat) -> CGFloat {
        guard expanded.width > 0, collapsed.width > 0 else { return expanded.height }
        let start = BrowserPageClipShape.tuckingStart
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
