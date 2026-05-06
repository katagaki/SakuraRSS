import Foundation

extension InstagramProvider {

    nonisolated static var feedURLScheme: String? { "instagram-profile" }

    nonisolated static func isProfileURL(_ url: URL) -> Bool {
        guard isInstagramHost(url.host) else { return false }

        let path = url.path
        guard path.count > 1 else { return false }

        let handle = String(path.dropFirst())
            .split(separator: "/").first.map(String.init) ?? ""
        guard !handle.isEmpty else { return false }

        let reserved: Set<String> = [
            "explore", "accounts", "p", "reel", "reels", "stories",
            "direct", "about", "legal", "developer", "api",
            "static", "emails", "challenge", "nux", "graphql"
        ]
        return !reserved.contains(handle.lowercased())
    }

    nonisolated static func extractIdentifier(from url: URL) -> String? {
        let path = url.path
        guard path.count > 1 else { return nil }
        return path.dropFirst()
            .split(separator: "/").first
            .map(String.init)
    }

    nonisolated static func feedURL(for identifier: String) -> String {
        "instagram-profile://\(identifier.lowercased())"
    }
}
