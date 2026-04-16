import Foundation

/// Standalone ad-label text patterns typically injected by news sites
/// (e.g. NYTimes "ADVERTISEMENT" paragraphs).
nonisolated enum AdvertisementTextFilter {

    static let patterns: Set<String> = [
        "advertisement",
        "advertising",
        "sponsored content",
        "paid post",
        "paid content"
    ]

    /// Returns true when the trimmed, lowercased text matches a known ad label.
    static func isAdvertisementText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return patterns.contains(trimmed)
    }
}
