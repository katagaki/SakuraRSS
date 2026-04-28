import Foundation

/// Caps how many feeds a user can follow on specific hosts to avoid bot-detection.
nonisolated enum FollowLimitSetDomains: DomainExceptions {

    static let limits: [String: Int] = [
        "x.com": 30,
        "instagram.com": 10
    ]

    static var exceptionDomains: Set<String> { Set(limits.keys) }

    /// Returns the follow limit for the given feed domain, or `nil` if unlimited.
    static func followLimit(for feedDomain: String) -> Int? {
        limitKey(for: feedDomain).flatMap { limits[$0] }
    }

    /// Returns the canonical host key a feed domain maps to.
    static func limitKey(for feedDomain: String) -> String? {
        matchedDomain(for: feedDomain)
    }
}
