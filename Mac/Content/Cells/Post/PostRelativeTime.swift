import Foundation

/// The relative timestamps iOS's `RelativeTimeText` shows in the Feed styles.
enum PostRelativeTime {

    private static let formatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        let languageCode = Locale.current.language.languageCode?.identifier ?? ""
        formatter.unitsStyle = ["ja", "ko", "zh"].contains(languageCode) ? .full : .abbreviated
        return formatter
    }()

    static func text(for date: Date) -> String {
        if Date().timeIntervalSince(date) < 60 {
            return String(localized: "Time.JustNow")
        }
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}
