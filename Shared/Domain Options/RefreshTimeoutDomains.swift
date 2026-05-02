import Foundation

/// Per-domain minimum interval between automatic refreshes, overriding the global cooldown.
nonisolated enum RefreshTimeoutDomains: DomainExceptions {

    static let timeouts: [String: TimeInterval] = [
        "x.com": 5 * 60,
        "instagram.com": 15 * 60
    ]

    static var exceptionDomains: Set<String> { Set(timeouts.keys) }

    /// Returns the refresh timeout (in seconds) for the given feed domain, or `nil` if none applies.
    /// `jittered` (default `true`) adds up to one third of the base interval to mask automation cadence.
    /// Pass `false` for stable values, e.g. driving a UI cooldown indicator.
    static func refreshTimeout(for feedDomain: String, jittered: Bool = true) -> TimeInterval? {
        guard let base = timeoutKey(for: feedDomain).flatMap({ timeouts[$0] }) else { return nil }
        guard jittered else { return base }
        return base + TimeInterval.random(in: 0...(base / 3))
    }

    /// Returns the canonical host key a feed domain maps to.
    static func timeoutKey(for feedDomain: String) -> String? {
        matchedDomain(for: feedDomain)
    }
}
