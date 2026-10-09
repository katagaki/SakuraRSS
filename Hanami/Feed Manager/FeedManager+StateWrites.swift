import Foundation

extension FeedManager {

    /// Serial so successive toggles of the same item land in the order they were made.
    private static let articleStateWriteQueue = DispatchQueue(
        label: "com.tsubuzaki.SakuraRSS.ArticleStateWrites",
        qos: .userInitiated
    )

    /// Runs a read/bookmark state write off the main thread; `completion` runs on
    /// the main thread once the write has landed, so reloads it triggers see it.
    func writeArticleState(
        _ write: @escaping @Sendable (DatabaseManager) -> Void,
        completion: (@MainActor () -> Void)? = nil
    ) {
        let databaseManager = database
        Self.articleStateWriteQueue.async {
            write(databaseManager)
            guard let completion else { return }
            DispatchQueue.main.async {
                completion()
            }
        }
    }
}
