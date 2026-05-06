import Foundation

struct SubstackPublicProfileLogo: Sendable {
    let url: URL
    /// True when the URL is the user's own `photo_url` (an arbitrary-aspect
    /// portrait) rather than a publication logo. Callers should center-crop.
    let isAuthorPhoto: Bool
}
