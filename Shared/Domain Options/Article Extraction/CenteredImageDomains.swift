import Foundation

/// Domains whose article thumbnail images should be aligned center instead of top.
nonisolated enum CenteredImageDomains: DomainDefaults {

    static let exceptionDomains: Set<String> = [
        "youtube.com",
        "youtu.be"
    ]

    static func shouldCenterImage(feedDomain: String) -> Bool {
        matches(feedDomain: feedDomain)
    }
}
