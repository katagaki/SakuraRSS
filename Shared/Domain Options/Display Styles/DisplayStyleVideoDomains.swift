import Foundation

/// Domains that should use the video feed display style by default.
nonisolated enum DisplayStyleVideoDomains: DomainExceptions {

    static let exceptionDomains: Set<String> = [
        "youtube.com",
        "youtu.be",
        "vimeo.com",
        "nicovideo.jp",
        "ch.nicovideo.jp"
    ]

    static func shouldPreferVideo(feedDomain: String) -> Bool {
        matches(feedDomain: feedDomain)
    }
}
