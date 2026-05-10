import Foundation

extension XProvider {

    nonisolated static var feedURLScheme: String? { "x-profile" }

    nonisolated static func isProfileURL(_ url: URL) -> Bool {
        guard isXHost(url.host) else { return false }

        let path = url.path
        guard path.count > 1 else { return false }

        let handle = String(path.dropFirst())
            .split(separator: "/").first.map(String.init) ?? ""
        guard !handle.isEmpty else { return false }

        let reserved: Set<String> = [
            "home", "explore", "search", "notifications", "messages",
            "settings", "login", "signup", "i", "intent", "hashtag",
            "compose", "tos", "privacy"
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
        "x-profile://\(identifier.lowercased())"
    }
}
