import Foundation

nonisolated extension PetalEngine {

    // MARK: - Flexible date parsing

    /// Parses timestamps using a handful of common formats.
    /// Falls back to `ISO8601DateFormatter` and the system-locale
    /// date parsers so the builder doesn't need a date-format
    /// picker for the most common cases.
    ///
    /// Package-internal because `PetalEngine+Parsing` calls it
    /// from across the file boundary.
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

    // `ISO8601DateFormatter` and `DateFormatter` have been
    // documented as thread-safe for read-only use since iOS 7/11
    // respectively, but Foundation has never marked them
    // `Sendable`.  These caches are only ever read - the setup
    // closures configure the formatters once at first access and
    // nothing mutates them afterwards - so `nonisolated(unsafe)`
    // is the correct Swift 6 escape hatch.

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

    nonisolated(unsafe) static let fallbackDateFormatters: [DateFormatter] = {
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
