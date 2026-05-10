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
