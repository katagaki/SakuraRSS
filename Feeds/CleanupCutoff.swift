import Foundation

nonisolated enum CleanupCutoff: String, CaseIterable, Identifiable, Sendable {
    case off
    case last24Hours
    case last7Days
    case last30Days

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .off:
            return String(localized: "Cleanup.Cutoff.Off", table: "DataManagement")
        case .last24Hours:
            return String(localized: "Cleanup.Last24Hours", table: "DataManagement")
        case .last7Days:
            return String(localized: "Cleanup.Last7Days", table: "DataManagement")
        case .last30Days:
            return String(localized: "Cleanup.Last30Days", table: "DataManagement")
        }
    }

    /// Boundary date: anything older than this is eligible for deletion.
    /// `nil` for `.off`, meaning automatic cleanup is disabled.
    func cutoffDate(referenceDate: Date = Date()) -> Date? {
        switch self {
        case .off:
            return nil
        case .last24Hours:
            return Calendar.current.date(byAdding: .day, value: -1, to: referenceDate)
        case .last7Days:
            return Calendar.current.date(byAdding: .day, value: -7, to: referenceDate)
        case .last30Days:
            return Calendar.current.date(byAdding: .day, value: -30, to: referenceDate)
        }
    }
}
