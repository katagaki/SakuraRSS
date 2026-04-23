import Foundation

/// Domains that should use the photos display style by default (e.g. image-centric social media).
nonisolated enum DisplayStylePhotosDomains {

    static let allowlistedDomains: Set<String> = [
        "instagram.com",
        "pixelfed.social",
        "pixelfed.tokyo"
    ]

    static func shouldPreferPhotoView(feedDomain: String) -> Bool {
        let host = feedDomain.lowercased()
        return allowlistedDomains.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
    }
}
