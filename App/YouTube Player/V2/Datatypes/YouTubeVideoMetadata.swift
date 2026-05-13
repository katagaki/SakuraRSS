import Foundation
import Hanami

/// Metadata for a single YouTube video, sourced from the InnerTube `player`
/// endpoint. Used to populate the player UI when the article has no backing
/// feed entry (e.g. ephemeral URLs opened via `sakura://open`).
nonisolated struct YouTubeVideoMetadata: Sendable {
    let videoId: String
    let title: String
    let uploader: String
    let description: String
    let publishDateString: String?
    let chapters: [YouTubeChapter]

    var publishDate: Date? {
        guard let publishDateString, !publishDateString.isEmpty else { return nil }
        return Self.dateFormatters
            .lazy
            .compactMap { $0.date(from: publishDateString) }
            .first
    }

    private static let dateFormatters: [DateFormatter] = {
        let formats = ["yyyy-MM-dd", "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ss.SSSZ"]
        return formats.map { format in
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .iso8601)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            return formatter
        }
    }()
}
