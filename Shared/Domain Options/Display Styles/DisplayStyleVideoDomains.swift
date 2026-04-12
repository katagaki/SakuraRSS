import Foundation

/// Domains that should use the video feed display style by default.
nonisolated enum DisplayStyleVideoDomains {

    static let allowlistedDomains: Set<String> = [
        "youtube.com",
        "youtu.be",
        "vimeo.com",
        "nicovideo.jp",
        "ch.nicovideo.jp"
    ]

    static func shouldPreferVideo(feedDomain: String) -> Bool {
        let host = feedDomain.lowercased()
        return allowlistedDomains.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
    }
}
