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
        for articleID: Int64,
        _ write: @escaping @Sendable (DatabaseManager) -> Void,
        completion: (@MainActor () -> Void)? = nil
    ) {
        articleStateWriteGeneration += 1
        articleStateWriteGenerations[articleID] = articleStateWriteGeneration
        let databaseManager = database
        Self.articleStateWriteQueue.async {
            write(databaseManager)
            guard let completion else { return }
            DispatchQueue.main.async {
                completion()
            }
        }
    }

    /// Returns the generation of the last write that has landed, for `pruneStagedChanges`.
    @discardableResult
    func waitForArticleStateWrites() -> Int {
        let generation = articleStateWriteGeneration
        Self.articleStateWriteQueue.sync {}
        return generation
    }

    func articleStateWritesFinished() async -> Int {
        let generation = articleStateWriteGeneration
        await withCheckedContinuation { continuation in
            Self.articleStateWriteQueue.async {
                continuation.resume()
            }
        }
        return generation
    }

    /// Writes queued after the reload began may be missing from what it loaded,
    /// so their staged changes stay until a later reload.
    func pruneStagedChanges(loadedArticleIDs: Set<Int64>, settledGeneration: Int) {
        let generations = articleStateWriteGenerations
        let isSettled = { (articleID: Int64) in
            loadedArticleIDs.contains(articleID) && (generations[articleID] ?? 0) <= settledGeneration
        }
        stagedReadChanges = stagedReadChanges.filter { !isSettled($0.key) }
        stagedBookmarkChanges = stagedBookmarkChanges.filter { !isSettled($0.key) }
        articleStateWriteGenerations = generations.filter { $0.value > settledGeneration }
    }
}
