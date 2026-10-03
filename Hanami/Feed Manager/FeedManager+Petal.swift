import Foundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

public extension FeedManager {

    // MARK: - Petal Feed Lifecycle

    @discardableResult
    func addPetalFeed(
        recipe: PetalRecipe,
        iconData: Data? = nil
    ) throws -> Feed? {
        guard !database.feedExists(url: recipe.feedURL) else {
            throw FeedError.alreadyExists
        }
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
        let feed = try database.feed(byURL: recipe.feedURL)

        if let feed, let iconData, let image = PlatformImage(data: iconData) {
            Task {
                await Iconography.shared.setCustomIcon(image, feedID: feed.id)
                await MainActor.run { self.notifyIconChange() }
            }
        }
        return feed
    }

    func updatePetalRecipe(
        feed: Feed,
        recipe: PetalRecipe
    ) throws {
        if recipe.feedURL != feed.url, database.feedExists(url: recipe.feedURL) {
            throw FeedError.alreadyExists
        }
        let previousRecipe = PetalStore.shared.recipe(id: recipe.id)
        try PetalStore.shared.save(recipe)
        do {
            try database.updateFeedDetails(
                id: feed.id,
                title: recipe.name,
                url: recipe.feedURL,
                customIconURL: feed.customIconURL,
                isTitleCustomized: true,
                siteURL: recipe.siteURL
            )
        } catch {
            if let previousRecipe {
                try? PetalStore.shared.save(previousRecipe)
            }
            throw error
        }
        captureUserFeedEdit(feedID: feed.id)
        if feed.title != recipe.name {
            generateAcronymIcon(feedID: feed.id, title: recipe.name)
        }
        loadFromDatabase()
        if let updatedFeed = feedsByID[feed.id] {
            Task { try? await refreshFeed(updatedFeed) }
        }
    }

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
            throw NSError(
                domain: "Petal", code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "Error.FetchFailed", table: "Petal")]
            )
        }
        log("Petal", "fetching recipeID=\(recipe.id) id=\(feed.id)")

        let result = await PetalEngine.preview(for: recipe)
        try Task.checkCancellation()
        if let errorMessage = result.errorMessage {
            throw NSError(
                domain: "Petal", code: 2,
                userInfo: [NSLocalizedDescriptionKey: errorMessage]
            )
        }
        let parsed = result.articles
        log("Petal", "fetched recipeID=\(recipe.id) articles=\(parsed.count)")

        let database = database
        let feedID = feed.id
        let feedTitle = feed.title
        let articleItems = Self.makePetalArticleItems(from: parsed)
        let pipelineTask = Task.detached {
            let insertedIDs = try database.insertArticles(
                feedID: feedID, articles: articleItems
            )
            log("Petal", "inserted id=\(feedID) new=\(insertedIDs.count)/\(articleItems.count)")
            await FeedManager.runPostInsertPipeline(
                insertedIDs: insertedIDs,
                feedTitle: feedTitle,
                skipImagePreload: skipImagePreload,
                runNLP: runNLP
            )
            try database.updateFeedLastFetched(id: feedID, date: Date())
        }
        try await withTaskCancellationHandler {
            try await pipelineTask.value
        } onCancel: {
            pipelineTask.cancel()
        }

        if reloadData {
            await loadFromDatabaseInBackground(animated: true)
        }
        log("Petal", "refresh end id=\(feed.id)")
    }

    private static func makePetalArticleItems(from parsed: [ParsedArticle]) -> [ArticleInsertItem] {
        parsed.map { article in
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
    }
}
