import Foundation

public nonisolated struct RedditWebPost: Decodable, Sendable {
    public let id: String
    public let title: String
    public let url: String
    public let author: String
    public let created: String

    public var publishedDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: created)
            ?? ISO8601DateFormatter().date(from: created)
    }
}
