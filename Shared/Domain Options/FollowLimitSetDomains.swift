import Foundation

/// Caps how many feeds a user can follow on specific hosts to avoid bot-detection.
nonisolated enum FollowLimitSetDomains {

    static let limits: [String: Int] = [
        "x.com": 30,
        "instagram.com": 10
    ]

    /// Returns the follow limit for the given feed domain, or `nil` if unlimited.
    static func followLimit(for feedDomain: String) -> Int? {
        guard let key = limitKey(for: feedDomain) else { return nil }
        return limits[key]
    }

    /// Returns the canonical host key a feed domain maps to.
    static func limitKey(for feedDomain: String) -> String? {
        let host = feedDomain.lowercased()
        if limits[host] != nil {
            return host
        }
        for source in limits.keys where host.hasSuffix(".\(source)") {
            return source
        }
        return nil
    }
}
