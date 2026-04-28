import Foundation

/// Domains that should use the photos display style by default (e.g. image-centric social media).
nonisolated enum DisplayStylePhotosDomains: DomainExceptions {

    static let exceptionDomains: Set<String> = [
        "instagram.com",
        "pixelfed.social",
        "pixelfed.tokyo"
    ]

    static func shouldPreferPhotoView(feedDomain: String) -> Bool {
        matches(feedDomain: feedDomain)
    }
}
