import Foundation

enum NLPProcessingCoordinator {

    /// Processes unprocessed articles if any NLP feature is enabled.
    /// Called after feed refresh completes.
    static func processNewArticlesIfEnabled() async {
        let defaults = UserDefaults.standard
        let similarContentEnabled = defaults.bool(forKey: "Intelligence.SimilarContent.Enabled")
        let topicsPeopleEnabled = defaults.bool(forKey: "Intelligence.TopicsPeople.Enabled")
        guard similarContentEnabled || topicsPeopleEnabled else { return }

        let db = DatabaseManager.shared
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 3600)

        await Task.detached(priority: .utility) {
            guard let ids = try? db.unprocessedArticleIDs(since: sevenDaysAgo, limit: 200) else { return }

            for (index, id) in ids.enumerated() {
                guard let article = try? db.article(byID: id) else { continue }
                processArticleSync(article, similarContent: similarContentEnabled,
                                   topicsPeople: topicsPeopleEnabled)

                if index > 0 && index % 50 == 0 {
                    await Task.yield()
                }
            }
        }.value
    }

    /// Processes a single article on-demand (e.g., from ArticleDetailView).
    static func processArticle(_ article: Article) async {
        let defaults = UserDefaults.standard
        let similarContentEnabled = defaults.bool(forKey: "Intelligence.SimilarContent.Enabled")
        let topicsPeopleEnabled = defaults.bool(forKey: "Intelligence.TopicsPeople.Enabled")

        await Task.detached(priority: .utility) {
            processArticleSync(article, similarContent: similarContentEnabled,
                               topicsPeople: topicsPeopleEnabled)
        }.value
    }

    private nonisolated static func processArticleSync(
        _ article: Article,
        similarContent: Bool,
        topicsPeople: Bool
    ) {
        let db = DatabaseManager.shared
        let text = [article.title, article.summary ?? ""]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        if similarContent {
            if let score = NLPProcessor.sentimentScore(for: text) {
                try? db.updateSentimentScore(score, for: article.id)
            }
        }

        if topicsPeople {
            let entities = NLPProcessor.extractEntities(from: text)
            if !entities.isEmpty {
                try? db.insertEntities(
                    entities.map { (name: $0.name, type: $0.type) },
                    for: article.id
                )
            }
        }

        try? db.markNLPProcessed(articleId: article.id)
    }
}
