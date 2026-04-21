import Foundation
import UIKit

extension FeedManager {

    // MARK: - Petal Feed Lifecycle

    /// Creates a new feed backed by a Petal recipe.  The recipe is
    /// saved to `PetalStore` and the feed's URL is set to
    /// `petal://<siteURL>` so `refreshFeed` dispatches to
    /// `PetalEngine` on every refresh.
    ///
    /// - Parameter recipe: the completed recipe from the builder.
    /// - Parameter iconData: an optional PNG payload imported from a
    ///   `.srss` package (user-supplied icons override the acronym
    ///   placeholder).
    @discardableResult
    func addPetalFeed(
        recipe: PetalRecipe,
        iconData: Data? = nil
    ) throws -> Feed? {
        try PetalStore.shared.save(recipe)
        if let iconData {
            try? PetalStore.shared.saveIcon(iconData, for: recipe.id)
        }
        try addFeed(
            url: recipe.feedURL,
            title: recipe.name,
            siteURL: recipe.siteURL,
            description: ""
        )
        let feed = feeds.first(where: { $0.url == recipe.feedURL })

        // Install the imported icon as the feed's custom favicon so
        // it flows through the existing FaviconCache pipeline.
        if let feed, let iconData, let image = UIImage(data: iconData) {
            Task {
                await FaviconCache.shared.setCustomFavicon(
                    image, feedID: feed.id, skipTrimming: true
                )
                await MainActor.run { self.notifyFaviconChange() }
            }
        }
        return feed
    }

    /// Updates the backing recipe for an existing Petal feed.
    /// Also refreshes the feed's title/siteURL in the database if the
    /// recipe's name or source URL changed.
    func updatePetalRecipe(
        feed: Feed,
        recipe: PetalRecipe
    ) throws {
        try PetalStore.shared.save(recipe)
        let titleChanged = feed.title != recipe.name
        let siteChanged = feed.siteURL != recipe.siteURL
        if titleChanged || siteChanged {
            try database.updateFeedDetails(
                id: feed.id,
                title: recipe.name,
                url: feed.url,
                customIconURL: feed.customIconURL,
                isTitleCustomized: true
            )
            if titleChanged {
                generateAcronymIcon(feedID: feed.id, title: recipe.name)
            }
            loadFromDatabase()
        }
    }

    /// Replacement for the RSS code path used by the normal refresh
    /// pipeline.  Mirrors `FeedManager+Refresh.swift`'s
    /// `refreshFeed(_:)` control flow but drives `PetalEngine`.
    func refreshPetalFeed(_ feed: Feed, reloadData: Bool) async throws {
        guard UserDefaults.standard.bool(forKey: "Labs.PetalRecipes") else {
            return
        }
        guard let recipe = PetalStore.shared.recipe(forFeedURL: feed.url) else {
            return
        }

        let parsed = await PetalEngine.fetchArticles(for: recipe)
        guard !parsed.isEmpty else {
            try? database.updateFeedLastFetched(id: feed.id, date: Date())
            if reloadData { await loadFromDatabaseInBackground(animated: true) }
            return
        }

        let database = database
        let feedID = feed.id
        try await Task.detached {
            let articleItems = parsed.map { article in
                ArticleInsertItem(
                    title: article.title,
                    url: article.url,
                    data: ArticleInsertData(
                        author: article.author,
                        summary: article.summary,
                        content: article.content,
                        imageURL: article.imageURL,
                        publishedDate: article.publishedDate ?? Date(),
                        audioURL: article.audioURL,
                        duration: article.duration
                    )
                )
            }
            try database.insertArticles(feedID: feedID, articles: articleItems)
            try database.updateFeedLastFetched(id: feedID, date: Date())
        }.value

        if reloadData {
            await loadFromDatabaseInBackground(animated: true)
        }
    }
}
