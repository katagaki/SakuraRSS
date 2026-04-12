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
///
/// Fetches that finish much faster than their expected duration would
/// otherwise flash the badge at near-zero fill and disappear, which is
/// too quick to read.  To guarantee visible feedback, `endFetch` marks
/// the entry as completed (the pie snaps to 100 %) and schedules the
/// removal after a short lingering interval.
@Observable
@MainActor
final class FetchProgressTracker {

    static let shared = FetchProgressTracker()

    /// Minimum time the badge stays visible after a fetch finishes.
    /// Ensures the user sees a full pie even when the underlying work
    /// completes in a few hundred milliseconds.
    private static let completedLinger: TimeInterval = 0.8

    struct Entry {
        let startDate: Date
        let duration: TimeInterval
        /// Monotonically-increasing token used to distinguish successive
        /// fetches for the same feed so delayed removals only affect the
        /// entry that scheduled them.
        let token: Int
        var completedAt: Date?
    }

    /// Active fetches keyed by feed ID.  Mutating this property triggers
    /// SwiftUI observation so that views automatically refresh when a
    /// fetch starts or ends.
    private(set) var activeFetches: [Int64: Entry] = [:]

    private var nextToken: Int = 0

    private init() {}

    func startFetch(feedID: Int64, duration: TimeInterval) {
        nextToken += 1
        activeFetches[feedID] = Entry(
            startDate: Date(),
            duration: duration,
            token: nextToken,
            completedAt: nil
        )
    }

    func endFetch(feedID: Int64) {
        guard var entry = activeFetches[feedID], entry.completedAt == nil else {
            return
        }
        entry.completedAt = Date()
        activeFetches[feedID] = entry
        let token = entry.token

        // Linger briefly so the user sees the pie reach 100 % even for
        // fast fetches, then remove — but only if this exact entry is
        // still the active one (a newer fetch for the same feed would
        // have bumped the token).
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.completedLinger))
            if FetchProgressTracker.shared.activeFetches[feedID]?.token == token {
                FetchProgressTracker.shared.activeFetches.removeValue(forKey: feedID)
            }
        }
    }

    /// Returns the completed fraction (0...1) of the fetch for the given
    /// feed, or `nil` if no fetch is currently active.  Completed fetches
    /// report 1.0 until they are removed from the tracker.
    func progress(for feedID: Int64, now: Date = Date()) -> Double? {
        guard let entry = activeFetches[feedID] else { return nil }
        if entry.completedAt != nil { return 1 }
        guard entry.duration > 0 else { return 1 }
        let elapsed = now.timeIntervalSince(entry.startDate)
        return min(max(elapsed / entry.duration, 0), 1)
    }
}
