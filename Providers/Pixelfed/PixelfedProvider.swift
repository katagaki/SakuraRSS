import Foundation

/// Fetches Pixelfed profile metadata by scraping the public profile page's
/// `og:image` tag. Pixelfed profile URLs follow `https://<host>/<username>`.
final class PixelfedProvider {

    nonisolated static let knownHosts: Set<String> = [
        "pixelfed.social",
        "pixelfed.tokyo",
        "pixelfed.art"
    ]

    nonisolated static func isPixelfedHost(_ host: String?) -> Bool {
        matchesHost(host)
    }

    /// Profile pages live at the bare `<host>/<username>` path on Pixelfed,
    /// not the `@username` form Mastodon uses.
    nonisolated static func profileURL(host: String, username: String) -> URL? {
        URL(string: "https://\(host)/\(username)")
    }

    // MARK: - Public

    func fetchProfile(host: String, username: String) async -> PixelfedProfileFetchResult {
        guard let url = Self.profileURL(host: host, username: username) else {
            log("PixelfedProfile", "fetch skip host=\(host) username=\(username) reason=bad-url")
            return PixelfedProfileFetchResult(profileImageURL: nil)
        }
        log("PixelfedProfile", "fetch begin url=\(url.absoluteString)")
        let started = Date()
        let imageURL = await HTMLMetadataImage.fetchImageURL(for: url)
        let elapsedMs = Int(Date().timeIntervalSince(started) * 1000)
        // swiftlint:disable:next line_length
        log("PixelfedProfile", "fetch end url=\(url.absoluteString) elapsedMs=\(elapsedMs) imageURL=\(imageURL ?? "nil")")
        return PixelfedProfileFetchResult(profileImageURL: imageURL)
    }
}
