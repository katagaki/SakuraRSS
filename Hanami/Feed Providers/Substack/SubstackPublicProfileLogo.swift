import Foundation

public struct SubstackPublicProfileLogo: Sendable {
    public let url: URL
    /// True when the URL is the user's own `photo_url` (an arbitrary-aspect
    /// portrait) rather than a publication logo. Callers should center-crop.
    public let isAuthorPhoto: Bool
}
