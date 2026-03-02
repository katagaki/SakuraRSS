import SwiftUI

/// Displays a date as localized relative time
/// (e.g. "5 minutes ago", "2 weeks ago", "3 months ago", "2週間前").
/// Articles less than a minute old show "Just now".
struct RelativeTimeText: View {

    let date: Date

    private static let formatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    var body: some View {
        Text(relativeString)
    }

    private var relativeString: String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return String(localized: "Time.JustNow")
        }

        return Self.formatter.localizedString(for: date, relativeTo: .now)
    }
}
