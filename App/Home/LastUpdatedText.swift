import Foundation

@MainActor
enum LastUpdatedText {

    private static var cache: [Date: String] = [:]
    private static var cachedMinute: Int = -1

    static func text(for date: Date?) -> String {
        let key = date ?? .distantPast
        let minute = Int(Date().timeIntervalSinceReferenceDate / 60)
        if minute != cachedMinute {
            cache.removeAll(keepingCapacity: true)
            cachedMinute = minute
        }
        if let cached = cache[key] {
            return cached
        }
        let relative: String
        if let date {
            relative = date.formatted(.relative(presentation: .named))
        } else {
            relative = Date().formatted(
                .dateTime
                    .weekday(.wide)
                    .month(.abbreviated)
                    .day()
            )
        }
        let value = String(localized: "Home.LastUpdated \(relative)", table: "Home")
        cache[key] = value
        return value
    }
}
