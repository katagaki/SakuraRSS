import Foundation
import UIKit

extension FeedManager {

    // MARK: - Petal Feed Lifecycle

    /// Creates a feed backed by a Petal recipe; the feed URL is `petal://<siteURL>`.
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

        if let feed, let iconData, let image = UIImage(data: iconData) {
            Task {
                await IconCache.shared.setCustomIcon(image, feedID: feed.id)
                await MainActor.run { self.notifyIconChange() }
            }
        }
        return feed
    }

    /// Updates the backing recipe for an existing Petal feed.
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

    // swiftlint:disable function_body_length
    /// Mirror of `refreshFeed(_:)` that drives `PetalEngine` instead of the RSS path.
    func refreshPetalFeed(
        _ feed: Feed,
        reloadData: Bool,
        skipImagePreload: Bool = false,
        runNLP: Bool = true
    ) async throws {
        log("Petal", "refresh begin id=\(feed.id) title=\(feed.title)")
        guard UserDefaults.standard.bool(forKey: "Labs.PetalRecipes") else {
            log("Petal", "Labs.PetalRecipes disabled - skipping id=\(feed.id)")
            return
        }
        guard let recipe = PetalStore.shared.recipe(forFeedURL: feed.url) else {
            log("Petal", "no recipe found id=\(feed.id) url=\(feed.url)")
            return
        }
        log("Petal", "fetching recipeID=\(recipe.id) id=\(feed.id)")

        let parsed = await PetalEngine.fetchArticles(for: recipe)
        log("Petal", "fetched recipeID=\(recipe.id) articles=\(parsed.count)")
        guard !parsed.isEmpty else {
            try? database.updateFeedLastFetched(id: feed.id, date: Date())
            if reloadData {
                await loadFromDatabaseInBackground(animated: true)
            }
            return
        }

        let database = database
        let feedID = feed.id
        let feedTitle = feed.title
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
            let insertedIDs = (try? database.insertArticles(
                feedID: feedID, articles: articleItems
            )) ?? []
            log("Petal", "inserted id=\(feedID) new=\(insertedIDs.count)/\(articleItems.count)")
            await FeedManager.runPostInsertPipeline(
                insertedIDs: insertedIDs,
                feedTitle: feedTitle,
                skipImagePreload: skipImagePreload,
                runNLP: runNLP
            )
            try database.updateFeedLastFetched(id: feedID, date: Date())
        }.value

        await MainActor.run { self.bumpDataRevision() }
        if reloadData {
            await loadFromDatabaseInBackground(animated: true)
        }
        log("Petal", "refresh end id=\(feed.id)")
    }
    // swiftlint:enable function_body_length
}
