import Foundation

/// Controls how the Home / Feed / List views paginate older articles behind
/// the "Show Older Content" affordance.  Date-based modes walk backwards in
/// fixed-size day windows; count-based modes grow a running limit by a fixed
/// number of items; `.off` loads everything up-front with no paging.
nonisolated enum BatchingMode: String, CaseIterable, Identifiable, Sendable {
    case off
    case day1
    case day3
    case week1
    case items25
    case items50
    case items100

    var id: String { rawValue }

    /// Number of days covered by one date-based batch, or `nil` for
    /// non-date-based modes.
    var chunkDays: Int? {
        switch self {
        case .day1: return 1
        case .day3: return 3
        case .week1: return 7
        default: return nil
        }
    }

    /// Number of items added per count-based batch, or `nil` for
    /// non-count-based modes.
    var batchSize: Int? {
        switch self {
        case .items25: return 25
        case .items50: return 50
        case .items100: return 100
        default: return nil
        }
    }

    var isDateBased: Bool { chunkDays != nil }
    var isCountBased: Bool { batchSize != nil }

    /// Date at which the initial batch should begin for date-based modes.
    /// Returns `.distantPast` for non-date-based modes so existing
    /// `articles(since:)` callers keep working.
    func initialSinceDate() -> Date {
        guard let days = chunkDays else { return Date(timeIntervalSince1970: 0) }
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return Calendar.current.date(byAdding: .day, value: -(days - 1), to: startOfToday)
            ?? startOfToday
    }

    /// Initial item count for the first count-based batch.
    func initialCount() -> Int { batchSize ?? 0 }

    /// The currently persisted mode, used to seed `@State` values so the
    /// initial window matches the stored configuration rather than the
    /// `@AppStorage` default.
    static func current() -> BatchingMode {
        let raw = UserDefaults.standard.string(forKey: "Articles.BatchingMode")
        return raw.flatMap(BatchingMode.init(rawValue:)) ?? .day1
    }
}
