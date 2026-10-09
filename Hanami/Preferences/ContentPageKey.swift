import Foundation

/// Identifies a page of content the same way on every device, so per-page
/// preferences can sync. Feeds use their URL because sync IDs are replaced
/// when two devices' copies of a feed are merged.
public nonisolated enum ContentPageKey {

    public static func feed(url: String) -> String {
        "feed:" + url
    }

    public static func list(syncID: String) -> String {
        "list:" + syncID
    }

    public static func section(_ section: FeedSection?) -> String {
        "section:" + (section?.rawValue ?? "all")
    }

    public static func topic(_ name: String) -> String {
        "topic:" + name
    }
}
