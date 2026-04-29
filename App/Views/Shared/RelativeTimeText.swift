import SwiftUI

/// Localized relative time text; sub-minute intervals render as "Just now".
struct RelativeTimeText: View {

    let date: Date

    private static let formatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        let lang = Locale.current.language.languageCode?.identifier ?? ""
        let useFull = ["ja", "ko", "zh"].contains(lang)
        formatter.unitsStyle = useFull ? .full : .abbreviated
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
