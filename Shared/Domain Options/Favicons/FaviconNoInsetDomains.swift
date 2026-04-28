import Foundation

/// Domains whose favicons should always be displayed at full size
/// inside a circle, skipping inset and background adjustments.
nonisolated enum FaviconNoInsetDomains: DomainExceptions {

    static let exceptionDomains: Set<String> = [
        "appleinsider.com",
        "atp.fm",
        "nikkei.com",
        "reddit.com",
        "wabetainfo.com",
        "vimeo.com"
    ]

    static func shouldUseFullImage(feedDomain: String) -> Bool {
        matches(feedDomain: feedDomain)
    }
}
