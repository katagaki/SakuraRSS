import Foundation

struct PixelfedProfileFetchResult: Sendable {
    let profileImageURL: String?
}

/// Fetches Pixelfed profile metadata by scraping the public profile page's
/// `og:image` tag. Pixelfed profile URLs follow `https://<host>/<username>`.
final class PixelfedProfileFetcher: ProfileFetcher {

    nonisolated static let knownHosts: Set<String> = [
        "pixelfed.social",
        "pixelfed.tokyo",
        "pixelfed.art"
    ]

    nonisolated static func isPixelfedHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return knownHosts.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
    }

    /// Profile pages live at the bare `<host>/<username>` path on Pixelfed,
    /// not the `@username` form Mastodon uses.
    nonisolated static func profileURL(host: String, username: String) -> URL? {
        URL(string: "https://\(host)/\(username)")
    }

    // MARK: - ProfileFetcher

    /// `nil` because Pixelfed feeds use a real `https://<host>/@<user>.rss`
    /// URL, not a pseudo-scheme. `isFeedURL`/`identifierFromFeedURL` are
    /// overridden below.
    nonisolated static var feedURLScheme: String? { nil }

    nonisolated static func isProfileURL(_ url: URL) -> Bool {
        guard isPixelfedHost(url.host) else { return false }
        let components = url.pathComponents.filter { $0 != "/" }
        guard let first = components.first, !first.isEmpty,
              !first.hasPrefix("@") else { return false }
        return true
    }

    nonisolated static func extractIdentifier(from url: URL) -> String? {
        guard isProfileURL(url) else { return nil }
        return url.pathComponents.filter { $0 != "/" }.first
    }

    nonisolated static func feedURL(for identifier: String) -> String {
        "https://pixelfed.social/@\(identifier).rss"
    }

    nonisolated static func isFeedURL(_ url: String) -> Bool {
        guard let parsed = URL(string: url),
              isPixelfedHost(parsed.host) else { return false }
        let path = parsed.path
        return path.hasPrefix("/@") && path.hasSuffix(".rss")
    }

    nonisolated static func identifierFromFeedURL(_ url: String) -> String? {
        guard isFeedURL(url),
              let parsed = URL(string: url) else { return nil }
        let trimmed = parsed.path.dropFirst(2).dropLast(4)
        let username = trimmed.split(separator: "/").first.map(String.init) ?? ""
        return username.isEmpty ? nil : username
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
