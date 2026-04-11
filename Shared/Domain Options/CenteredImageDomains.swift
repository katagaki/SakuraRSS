import Foundation

/// Domains whose article thumbnail images should be aligned center instead of top.
nonisolated enum CenteredImageDomains {

    static let allowlistedDomains: Set<String> = [
        "youtube.com",
        "youtu.be"
    ]

    static func shouldCenterImage(feedDomain: String) -> Bool {
        let host = feedDomain.lowercased()
        return allowlistedDomains.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
    }
}
