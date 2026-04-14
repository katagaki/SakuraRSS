import Foundation

/// Caps how many feeds a user can follow on specific hosts.
///
/// Hosts with an entry here are scraped via authenticated flows (X,
/// Instagram) where hitting the upstream API at an unbounded cadence
/// is a strong bot-like signal and invites rate-limit or account-lock
/// penalties.  The limit is enforced in `FeedManager.addFeed` before
/// any insert happens, so the cap applies to every path that adds a
/// feed (Add Feed sheet, share extension, OPML import, etc.).
nonisolated enum FollowLimitSetDomains {

    /// Maximum followed feeds per host.  Keys match `URL.host` output
    /// (lowercased, no scheme or trailing slash).  Subdomains of a
    /// listed host share the same cap.
    static let limits: [String: Int] = [
        "x.com": 30,
        "instagram.com": 10
    ]

    /// Returns the follow limit that applies to the given feed domain,
    /// or `nil` if no limit is configured for the host.
    static func followLimit(for feedDomain: String) -> Int? {
        guard let key = limitKey(for: feedDomain) else { return nil }
        return limits[key]
    }

    /// Returns the canonical host key a feed domain maps to — e.g.
    /// both `www.x.com` and `x.com` resolve to `"x.com"`.  Used to
    /// group existing feeds by their limit bucket when enforcing the
    /// cap.  Returns `nil` when no bucket applies.
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
