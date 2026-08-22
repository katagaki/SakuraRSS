import Foundation

public nonisolated extension RSSParser {

    // MARK: - Date Parsing

    private static let zonedDateFormats = [
        "EEE, dd MMM yyyy HH:mm:ss Z",
        "EEE, dd MMM yyyy HH:mm:ss zzz",
        "EEE, dd MMM yyyy HH:mm Z",
        "EEE, dd MMM yyyy HH:mm zzz",
        "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
        "yyyy-MM-dd'T'HH:mm:ssZ"
    ]

    private static let zonelessDateFormats = [
        "EEE, dd MMM yyyy HH:mm:ss",
        "EEE, dd MMM yyyy HH:mm",
        "yyyy-MM-dd'T'HH:mm:ss.SSS",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd"
    ]

    private static let dateFormatters: [DateFormatter] = {
        let zoned = RSSParser.zonedDateFormats.map { RSSParser.makeDateFormatter(format: $0, timeZone: nil) }
        let utc = TimeZone(secondsFromGMT: 0)
        let zoneless = RSSParser.zonelessDateFormats.map { RSSParser.makeDateFormatter(format: $0, timeZone: utc) }
        return zoned + zoneless
    }()

    private static func makeDateFormatter(format: String, timeZone: TimeZone?) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        if let timeZone {
            formatter.timeZone = timeZone
        }
        return formatter
    }

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

        var components: [Int] = []
        for component in trimmed.split(separator: ":", omittingEmptySubsequences: false) {
            guard let value = Self.durationComponentValue(component) else { return nil }
            components.append(value)
        }

        switch components.count {
        case 1: return components[0]
        case 2: return components[0] * 60 + components[1]
        case 3: return components[0] * 3600 + components[1] * 60 + components[2]
        default: return nil
        }
    }

    private static func durationComponentValue(_ component: Substring) -> Int? {
        let trimmed = component.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        guard let separatorIndex = trimmed.firstIndex(where: { $0 == "." || $0 == "," }) else {
            return Int(trimmed)
        }
        let whole = trimmed[trimmed.startIndex..<separatorIndex]
        let fraction = trimmed[trimmed.index(after: separatorIndex)...]
        guard !whole.isEmpty, !fraction.isEmpty, fraction.allSatisfy({ $0.isNumber }) else {
            return nil
        }
        return Int(whole)
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
