import Foundation

nonisolated extension PetalEngine {

    // MARK: - Flexible date parsing

    /// Parses timestamps using ISO8601 and a handful of common fallback formats.
    static func parseFlexibleDate(_ raw: String) -> Date? {
        if let iso = isoFormatter.date(from: raw) {
            return iso
        }
        if let isoFractional = isoFractionalFormatter.date(from: raw) {
            return isoFractional
        }
        for formatter in fallbackDateFormatters {
            if let date = formatter.date(from: raw) {
                return date
            }
        }
        return nil
    }

    // MARK: - Formatter caches

    // Foundation date formatters are thread-safe for read-only use but not Sendable,
    // so `nonisolated(unsafe)` is used since these caches are never mutated after setup.

    nonisolated(unsafe) static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    nonisolated(unsafe) static let isoFractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let fallbackDateFormatters: [DateFormatter] = {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
            "MMMM d, yyyy",
            "MMM d, yyyy",
            "d MMMM yyyy",
            "d MMM yyyy",
            "EEE, d MMM yyyy HH:mm:ss Z"
        ]
        return formats.map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            return formatter
        }
    }()
}
