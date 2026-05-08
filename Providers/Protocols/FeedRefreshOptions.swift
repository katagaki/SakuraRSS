import Foundation

/// Options forwarded through the feed-refresh pipeline.
struct FeedRefreshOptions: Sendable {
    let reloadData: Bool
    let skipImagePreload: Bool
    let runNLP: Bool
    let contentOnly: Bool
}
