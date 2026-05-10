import Foundation

/// A list of domains that opt into (or out of) some non-default behaviour.
///
/// Conformers declare `exceptionDomains` (the set of canonical host strings);
/// the protocol provides default `matches(feedDomain:)` and `matches(url:)`
/// helpers that handle the standard `host == domain || host.hasSuffix(".\(domain)")`
/// subdomain rule.
protocol DomainDefaults {

    /// Lowercased canonical host strings that match this exception list.
    nonisolated static var exceptionDomains: Set<String> { get }
}

extension DomainDefaults {

    /// Returns the matched canonical domain (key into `exceptionDomains`), or `nil`.
    /// Useful when conformers need the matched key to look up associated metadata.
    nonisolated static func matchedDomain(for feedDomain: String) -> String? {
        let host = feedDomain.lowercased()
        if exceptionDomains.contains(host) { return host }
        return exceptionDomains.first { host.hasSuffix(".\($0)") }
    }

    nonisolated static func matchedDomain(for url: URL) -> String? {
        guard let host = url.host?.lowercased() else { return nil }
        return matchedDomain(for: host)
    }

    nonisolated static func matches(feedDomain: String) -> Bool {
        matchedDomain(for: feedDomain) != nil
    }

    nonisolated static func matches(url: URL) -> Bool {
        matchedDomain(for: url) != nil
    }
}
