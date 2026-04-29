import Foundation

/// Display metadata for a feed source.
struct FetchedFeedMetadata: Sendable {
    let displayName: String?
    let iconURL: URL?
    /// True when the icon source isn't guaranteed square (e.g. an author
    /// photo) and should be center-cropped to its largest square after download.
    let iconNeedsSquareCrop: Bool

    init(displayName: String?, iconURL: URL?, iconNeedsSquareCrop: Bool = false) {
        self.displayName = displayName
        self.iconURL = iconURL
        self.iconNeedsSquareCrop = iconNeedsSquareCrop
    }
}

/// A provider that knows how to fetch its own display metadata
/// (feed name, feed icon) from a custom source.
protocol MetadataFetchingProvider: FeedProvider {

    /// True if this provider can fetch metadata for the given site URL.
    /// Distinct from `matchesFeedURL`, which matches the stored feed URL.
    nonisolated static func canFetchMetadata(for url: URL) -> Bool

    /// Fetches metadata for the given site URL, or `nil` if unavailable.
    static func fetchMetadata(for url: URL) async -> FetchedFeedMetadata?

    /// Brand fallback icon used when `fetchMetadata` cannot resolve a
    /// provider-specific icon (e.g. publication has no custom logo).
    nonisolated static var fallbackIconURL: URL? { get }
}

extension MetadataFetchingProvider {
    nonisolated static var fallbackIconURL: URL? { nil }
}
