import SwiftUI

/// Clips the page to the card's rect while it collapses. A shape rather than a
/// frame so the crop costs nothing but a mask: animating the frame would re-lay
/// the page out on every tick.
nonisolated struct BrowserPageClipShape: Shape {

    var rect: CGRect
    var cornerRadius: CGFloat

    var animatableData: AnimatablePair<
        AnimatablePair<CGFloat, CGFloat>,
        AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat>
    > {
        get {
            AnimatablePair(
                AnimatablePair(rect.origin.x, rect.origin.y),
                AnimatablePair(AnimatablePair(rect.width, rect.height), cornerRadius)
            )
        }
        set {
            rect = CGRect(
                x: newValue.first.first,
                y: newValue.first.second,
                width: newValue.second.first.first,
                height: newValue.second.first.second
            )
            cornerRadius = newValue.second.second
        }
    }

    func path(in bounds: CGRect) -> Path {
        Path(roundedRect: rect, cornerRadius: cornerRadius, style: .continuous)
    }
}
