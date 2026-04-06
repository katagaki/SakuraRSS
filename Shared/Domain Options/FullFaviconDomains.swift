import Foundation

/// Domains whose favicons should always be displayed at full size
/// inside a circle, skipping inset and background adjustments.
nonisolated enum FullFaviconDomains {

    static let allowlistedDomains: Set<String> = [
        "appleinsider.com",
        "nikkei.com"
    ]

    static func shouldUseFullImage(feedDomain: String) -> Bool {
        let host = feedDomain.lowercased()
        return allowlistedDomains.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
    }
}
