import Foundation
import Observation

/// Tracks in-flight feed fetches that have a bounded timeout so that the
/// UI can surface their progress as a pie overlay on the feed's favicon.
///
/// Currently used by X and Instagram profile refreshes, whose underlying
/// GraphQL / REST calls carry a hard per-request timeout.  When a refresh
/// starts, the fetch manager registers a deadline with this tracker; the
/// `FaviconProgressBadge` view then reads the deadline and draws a filled
/// pie that advances from empty to full as the timeout elapses.
@Observable
@MainActor
final class FetchProgressTracker {

    static let shared = FetchProgressTracker()

    struct Entry {
        let startDate: Date
        let duration: TimeInterval
    }

    /// Active fetches keyed by feed ID.  Mutating this property triggers
    /// SwiftUI observation so that views automatically refresh when a
    /// fetch starts or ends.
    private(set) var activeFetches: [Int64: Entry] = [:]

    private init() {}

    func startFetch(feedID: Int64, duration: TimeInterval) {
        activeFetches[feedID] = Entry(startDate: Date(), duration: duration)
    }

    func endFetch(feedID: Int64) {
        activeFetches.removeValue(forKey: feedID)
    }

    /// Returns the completed fraction (0...1) of the fetch for the given
    /// feed, or `nil` if no fetch is currently active.
    func progress(for feedID: Int64, now: Date = Date()) -> Double? {
        guard let entry = activeFetches[feedID] else { return nil }
        guard entry.duration > 0 else { return 1 }
        let elapsed = now.timeIntervalSince(entry.startDate)
        return min(max(elapsed / entry.duration, 0), 1)
    }
}
