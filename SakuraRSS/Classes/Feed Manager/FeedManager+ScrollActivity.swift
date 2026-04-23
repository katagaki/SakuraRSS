import SwiftUI

extension FeedManager {

    static let scrollVelocityIdleThreshold: CGFloat = 120

    /// True when the scroll view is idle and its velocity has decayed
    /// below the threshold for committing mark-as-read writes.
    var isScrollSettled: Bool {
        guard currentScrollPhase == .idle else { return false }
        return abs(currentScrollVelocity) < FeedManager.scrollVelocityIdleThreshold
    }

    func updateScrollPhase(_ phase: ScrollPhase) {
        currentScrollPhase = phase
        if phase == .idle {
            currentScrollVelocity = 0
        }
    }

    func updateScrollOffset(_ offset: CGFloat) {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = now - lastScrollSampleTime
        if lastScrollSampleTime > 0, dt > 0 {
            let instantaneous = (offset - lastScrollOffset) / CGFloat(dt)
            currentScrollVelocity = currentScrollVelocity * 0.5 + instantaneous * 0.5
        }
        lastScrollOffset = offset
        lastScrollSampleTime = now
    }

}
