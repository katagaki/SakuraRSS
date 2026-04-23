import SwiftUI

enum ScrollDirection: Sendable {
    case none, up, down
}

extension FeedManager {

    /// Minimum per-sample offset delta to switch direction, in points.
    /// Below this the scroll is treated as noise and direction is sticky.
    private static let scrollDirectionDeadband: CGFloat = 1

    func updateScrollPhase(_ phase: ScrollPhase) {
        currentScrollPhase = phase
    }

    /// Updates `currentScrollDirection` from the running offset. Direction
    /// persists after scrolling stops so visibility callbacks that fire
    /// on the trailing edge of a flick can still read a meaningful value.
    func updateScrollOffset(_ offset: CGFloat) {
        let delta = offset - lastScrollOffset
        if delta > FeedManager.scrollDirectionDeadband {
            currentScrollDirection = .down
        } else if delta < -FeedManager.scrollDirectionDeadband {
            currentScrollDirection = .up
        }
        lastScrollOffset = offset
        lastScrollSampleTime = ProcessInfo.processInfo.systemUptime
    }

}
