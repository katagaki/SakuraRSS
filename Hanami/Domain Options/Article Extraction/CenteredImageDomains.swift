import Foundation

/// Domains whose article thumbnail images should be aligned center instead of top.
public nonisolated enum CenteredImageDomains: DomainDefaults {

    public static let exceptionDomains: Set<String> = [
        "youtube.com",
        "youtu.be"
    ]

    public static func shouldCenterImage(feedDomain: String) -> Bool {
        matches(feedDomain: feedDomain)
    }
}
