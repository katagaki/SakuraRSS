import Foundation

/// Options forwarded through the feed-refresh pipeline.
public struct FeedRefreshOptions: Sendable {
    public let reloadData: Bool
    public let skipImagePreload: Bool
    public let runNLP: Bool
    public let contentOnly: Bool
}
