import SwiftUI

struct SimilarArticleItem: Identifiable {
    let id: Int64
    let article: Article
    let feedName: String
    let isSocialFeed: Bool
    let sentiment: Double?
    let favicon: UIImage?
}

extension ArticleDetailView {

    @ViewBuilder
    var insightsSection: some View {
        if shouldShowInsightsSection {
            VStack(alignment: .leading, spacing: 20) {
                Divider()
                    .padding(.horizontal)

                Label(String(localized: "Insights.Title", table: "Settings"), systemImage: "sparkles")
                    .font(.title3)
                    .fontWeight(.bold)
                    .padding(.horizontal)

                if isLoadingInsights {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                        .transition(.blurReplace)
                } else {
                    if !similarArticles.isEmpty {
                        similarContentSubsection
                    }

                    if !articleTopics.isEmpty {
                        entityChipsSubsection(
                            titleKey: String(localized: "SimilarContent.Topics", table: "Articles"),
                            systemImage: "number",
                            types: ["organization", "place"],
                            names: articleTopics
                        )
                    }

                    if !articlePeople.isEmpty {
                        entityChipsSubsection(
                            titleKey: String(localized: "SimilarContent.People", table: "Articles"),
                            systemImage: "person.2",
                            types: ["person"],
                            names: articlePeople
                        )
                    }
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }

    private var shouldShowInsightsSection: Bool {
        guard contentInsightsEnabled else { return false }
        return isLoadingInsights || hasAnyInsights
    }

    private var hasAnyInsights: Bool {
        !similarArticles.isEmpty || !articleTopics.isEmpty || !articlePeople.isEmpty
    }

    @ViewBuilder
    private var similarContentSubsection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(String(localized: "SimilarContent.Title", table: "Articles"), systemImage: "square.stack.3d.up")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(similarArticles) { item in
                        ArticleLink(article: item.article) {
                            SimilarArticleCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private func entityChipsSubsection(
        titleKey: String,
        systemImage: String,
        types: [String],
        names: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(titleKey, systemImage: systemImage)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(names, id: \.self) { name in
                        NavigationLink(value: EntityDestination(name: name, types: types)) {
                            Text(name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.regularMaterial, in: Capsule())
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    /// Kicks off similar/topic/people loading off MainActor.
    func loadInsightsInBackground() {
        guard contentInsightsEnabled else { return }
        let currentArticle = article
        let feedsLookup = feedManager.feedsByID

        isLoadingInsights = true
        Task {
            async let similarTask = Self.computeSimilarArticles(
                currentArticle: currentArticle, feedsLookup: feedsLookup
            )
            async let entitiesTask = Self.computeArticleEntities(
                articleID: currentArticle.id,
                articleTitle: currentArticle.title,
                articleSummary: currentArticle.summary ?? ""
            )
            let loadedSimilar = await similarTask
            let loadedEntities = await entitiesTask

            similarArticles = loadedSimilar
            articleTopics = loadedEntities.topics
            articlePeople = loadedEntities.people
            isLoadingInsights = false
        }
    }

    /// Runs entity extraction off the main actor using Sendable inputs.
    fileprivate nonisolated static func computeArticleEntities(
        articleID: Int64,
        articleTitle: String,
        articleSummary: String
    ) async -> (topics: [String], people: [String]) {
        let db = DatabaseManager.shared
        return await Task.detached(priority: .userInitiated) {
            if (try? db.isEntitiesProcessed(articleId: articleID)) != true {
                let text = [articleTitle, articleSummary]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                let entities = NLPProcessor.extractEntities(from: text)
                if !entities.isEmpty {
                    try? db.insertEntities(
                        entities.map { (name: $0.name, type: $0.type) },
                        for: articleID
                    )
                }
                try? db.markEntitiesProcessed(articleId: articleID)
            }

            guard let rows = try? db.entities(forArticleID: articleID) else {
                return (topics: [String](), people: [String]())
            }
            var topics: [String] = []
            var people: [String] = []
            var seenTopics = Set<String>()
            var seenPeople = Set<String>()
            for row in rows {
                let key = row.name.lowercased()
                switch row.type {
                case "person":
                    if seenPeople.insert(key).inserted { people.append(row.name) }
                case "organization", "place":
                    if seenTopics.insert(key).inserted { topics.append(row.name) }
                default:
                    break
                }
            }
            return (topics: topics, people: people)
        }.value
    }

    /// Runs similar-article discovery off the main actor.
    fileprivate nonisolated static func computeSimilarArticles(
        currentArticle: Article,
        feedsLookup: [Int64: Feed]
    ) async -> [SimilarArticleItem] {
        let rawMatches = await Task.detached(priority: .userInitiated) {
            await computeRawMatches(
                currentArticle: currentArticle, feedsLookup: feedsLookup
            )
        }.value

        return await withTaskGroup(of: (Int, SimilarArticleItem).self) { group in
            for (index, match) in rawMatches.enumerated() {
                group.addTask {
                    let favicon: UIImage?
                    if let feed = match.feed {
                        favicon = await FaviconCache.shared.favicon(for: feed)
                    } else {
                        favicon = nil
                    }
                    return (index, SimilarArticleItem(
                        id: match.article.id,
                        article: match.article,
                        feedName: match.feedName,
                        isSocialFeed: match.feed?.isSocialFeed ?? false,
                        sentiment: match.sentiment,
                        favicon: favicon
                    ))
                }
            }
            var results = [SimilarArticleItem?](repeating: nil, count: rawMatches.count)
            for await (index, item) in group {
                results[index] = item
            }
            return results.compactMap { $0 }
        }
    }

    /// Returns match metadata ordered by hybrid similarity score.
    fileprivate nonisolated static func computeRawMatches(
        currentArticle: Article,
        feedsLookup: [Int64: Feed]
    ) async -> [SimilarMatchData] {
        let db = DatabaseManager.shared

        if (try? db.isSimilarComputed(articleId: currentArticle.id)) == true {
            if let cached = try? db.cachedSimilarArticleIDs(forSourceID: currentArticle.id),
               !cached.isEmpty {
                var results: [SimilarMatchData] = []
                results.reserveCapacity(cached.count)
                for entry in cached {
                    guard let matchArticle = try? db.article(byID: entry.id) else { continue }
                    let feed = feedsLookup[matchArticle.feedID]
                    let sentiment = try? db.sentimentScore(for: entry.id)
                    results.append(SimilarMatchData(
                        article: matchArticle,
                        feedName: feed?.title ?? "",
                        feed: feed,
                        sentiment: sentiment
                    ))
                }
                return results
            }
            // Empty cache means computed earlier with no matches; skip recompute.
            return []
        }

        guard let candidates = try? db.articlesInWindow(
            around: currentArticle, hours: 168, limit: 82
        ), !candidates.isEmpty else {
            try? db.cacheSimilarArticles([], forSourceID: currentArticle.id)
            return []
        }

        if (try? db.isEntitiesProcessed(articleId: currentArticle.id)) != true {
            let sourceText = [currentArticle.title, currentArticle.summary ?? ""]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            let extracted = NLPProcessor.extractEntities(from: sourceText)
            if !extracted.isEmpty {
                try? db.insertEntities(
                    extracted.map { (name: $0.name, type: $0.type) },
                    for: currentArticle.id
                )
            }
            try? db.markEntitiesProcessed(articleId: currentArticle.id)
        }

        let sourceEntities: Set<String> = (try? db.entities(forArticleID: currentArticle.id))
            .map { Set($0.map { $0.name.lowercased() }) } ?? []
        let candidateIDs = candidates.map { $0.id }
        let entityMap = (try? db.entities(forArticleIDs: candidateIDs)) ?? [:]
        let pairs: [(article: Article, entities: Set<String>)] = candidates.map { candidate in
            (article: candidate, entities: entityMap[candidate.id] ?? [])
        }

        let similar = await NLPProcessor.findSimilarArticlesHybrid(
            to: currentArticle,
            sourceEntities: sourceEntities,
            candidates: pairs,
            maxResults: 8,
            minimumScore: 0.35
        )

        // Persist `1 - score` as distance so lower-is-better matches the cache reader.
        try? db.cacheSimilarArticles(
            similar.map { (id: $0.articleID, distance: 1.0 - $0.score) },
            forSourceID: currentArticle.id
        )

        var results: [SimilarMatchData] = []
        results.reserveCapacity(similar.count)
        for match in similar {
            guard let matchArticle = try? db.article(byID: match.articleID) else { continue }
            let feed = feedsLookup[matchArticle.feedID]
            let sentiment = try? db.sentimentScore(for: match.articleID)
            results.append(SimilarMatchData(
                article: matchArticle,
                feedName: feed?.title ?? "",
                feed: feed,
                sentiment: sentiment
            ))
        }
        return results
    }
}

private struct SimilarMatchData: Sendable {
    let article: Article
    let feedName: String
    let feed: Feed?
    let sentiment: Double?
}

// MARK: - Card

private struct SimilarArticleCard: View {

    @Environment(\.zoomNamespace) private var zoomNamespace
    let item: SimilarArticleItem

    private let cardWidth: CGFloat = 240
    private let imageHeight: CGFloat = 135

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardVisual
                .frame(width: cardWidth, height: imageHeight)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.quaternary, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                .zoomSource(id: item.article.id, namespace: zoomNamespace)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.article.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                Text(item.feedName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: cardWidth, alignment: .leading)
        }
    }

    @ViewBuilder
    private var cardVisual: some View {
        if let imageURL = item.article.imageURL, let url = URL(string: imageURL) {
            CachedAsyncImage(url: url, alignment: .top) {
                thumbnailBackground
            }
        } else {
            thumbnailBackground
        }
    }

    private var thumbnailBackground: some View {
        FeedIconPlaceholder(
            favicon: item.favicon,
            acronymIcon: nil,
            feedName: item.feedName,
            isSocialFeed: item.isSocialFeed,
            iconSize: imageHeight * 0.5,
            fallback: .symbol("doc.text")
        )
    }
}
