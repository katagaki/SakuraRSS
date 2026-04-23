import Foundation

/// Controls how views paginate older articles (by day windows, item count, or off).
nonisolated enum BatchingMode: String, CaseIterable, Identifiable, Sendable {
    case off
    case day1
    case day3
    case week1
    case items25
    case items50
    case items100

    var id: String { rawValue }

    /// Days per date-based batch, or `nil`.
    var chunkDays: Int? {
        switch self {
        case .day1: return 1
        case .day3: return 3
        case .week1: return 7
        default: return nil
        }
    }

    /// Items per count-based batch, or `nil`.
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

    /// Start date for the initial date-based batch (epoch for non-date modes).
    func initialSinceDate() -> Date {
        guard let days = chunkDays else { return Date(timeIntervalSince1970: 0) }
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return Calendar.current.date(byAdding: .day, value: -(days - 1), to: startOfToday)
            ?? startOfToday
    }

    func initialCount() -> Int { batchSize ?? 0 }

    /// Returns the currently persisted mode.
    static func current() -> BatchingMode {
        let raw = UserDefaults.standard.string(forKey: "Articles.BatchingMode")
        return raw.flatMap(BatchingMode.init(rawValue:)) ?? .day1
    }
}
