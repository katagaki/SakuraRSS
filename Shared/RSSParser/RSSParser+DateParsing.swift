import Foundation

nonisolated extension RSSParser {

    // MARK: - Date Parsing

    private static let dateFormatters: [DateFormatter] = {
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        ]
        return formats.map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            return formatter
        }
    }()

    nonisolated(unsafe) private static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    nonisolated(unsafe) private static let iso8601Standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    func parseDuration(_ string: String) -> Int? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let components = trimmed.split(separator: ":").compactMap { Int($0) }
        switch components.count {
        case 1: return components[0]
        case 2: return components[0] * 60 + components[1]
        case 3: return components[0] * 3600 + components[1] * 60 + components[2]
        default: return nil
        }
    }

    func parseDate(_ string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        for formatter in Self.dateFormatters {
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }

        return Self.iso8601WithFractional.date(from: trimmed)
            ?? Self.iso8601Standard.date(from: trimmed)
    }
}
