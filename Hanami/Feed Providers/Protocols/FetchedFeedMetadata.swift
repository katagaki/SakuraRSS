import Foundation

/// Display metadata for a feed source.
public struct FetchedFeedMetadata: Sendable {
    public let displayName: String?
    public let iconURL: URL?
    /// True when the icon source isn't guaranteed square (e.g. an author
    /// photo) and should be center-cropped to its largest square after download.
    public let iconNeedsSquareCrop: Bool

    public init(displayName: String?, iconURL: URL?, iconNeedsSquareCrop: Bool = false) {
        self.displayName = displayName
        self.iconURL = iconURL
        self.iconNeedsSquareCrop = iconNeedsSquareCrop
    }
}
