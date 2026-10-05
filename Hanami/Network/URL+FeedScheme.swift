import Foundation

public extension URL {

    /// The web address behind a `feed:` or `feeds:` link, in either its
    /// `feed:https://…` or `feed://…` form.
    nonisolated var resolvingFeedScheme: String {
        let urlString = absoluteString
        for scheme in ["feed", "feeds"] {
            if urlString.hasPrefix("\(scheme):https://") || urlString.hasPrefix("\(scheme):http://") {
                return String(urlString.dropFirst(scheme.count + 1))
            }
            if urlString.hasPrefix("\(scheme)://") {
                return "https://" + urlString.dropFirst(scheme.count + 3)
            }
        }
        return urlString
    }
}
