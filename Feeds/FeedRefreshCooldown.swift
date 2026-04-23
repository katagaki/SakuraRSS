import Foundation

/// Cooldown between automatic per-feed refreshes (does not affect user-triggered pull-to-refresh).
nonisolated enum FeedRefreshCooldown: String, CaseIterable, Sendable {
    case off
    case oneMinute
    case fiveMinutes
    case tenMinutes
    case thirtyMinutes
    case oneHour

    /// Seconds to enforce, or `nil` when cooldown is disabled.
    var seconds: TimeInterval? {
        switch self {
        case .off: return nil
        case .oneMinute: return 60
        case .fiveMinutes: return 5 * 60
        case .tenMinutes: return 10 * 60
        case .thirtyMinutes: return 30 * 60
        case .oneHour: return 60 * 60
        }
    }
}
