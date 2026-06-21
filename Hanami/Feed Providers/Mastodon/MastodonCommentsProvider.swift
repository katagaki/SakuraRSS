import Foundation

/// Comments-only provider that surfaces the public reply thread of a Mastodon
/// status as an article's conversation. It never claims feed routing.
public nonisolated enum MastodonCommentsProvider {

    public static func isMastodonStatusURL(_ url: URL) -> Bool {
        statusID(from: url) != nil
    }

    static func statusID(from url: URL) -> String? {
        let components = url.pathComponents
        if components.count == 3,
           components[1].hasPrefix("@"),
           isNumeric(components[2]) {
            return components[2]
        }
        if components.count == 5,
           components[1].lowercased() == "users",
           components[3].lowercased() == "statuses",
           isNumeric(components[4]) {
            return components[4]
        }
        if components.count == 4,
           components[1].lowercased() == "web",
           components[2].lowercased() == "statuses",
           isNumeric(components[3]) {
            return components[3]
        }
        return nil
    }

    static func contextURL(forStatusID statusID: String, host: String) -> URL? {
        URL(string: "https://\(host)/api/v1/statuses/\(statusID)/context")
    }

    private static func isNumeric(_ value: String) -> Bool {
        !value.isEmpty && value.allSatisfy { $0.isNumber }
    }
}

extension MastodonCommentsProvider: FeedProvider {

    public nonisolated static var providerID: String { "mastodon" }

    public nonisolated static var domains: Set<String> { [] }

    public nonisolated static func matchesFeedURL(_ feedURL: String) -> Bool { false }
}
