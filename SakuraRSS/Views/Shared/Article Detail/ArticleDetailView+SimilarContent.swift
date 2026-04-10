import SwiftUI

struct SimilarArticleItem: Identifiable {
    let id: Int64
    let article: Article
    let feedName: String
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

                Label("Insights.Title", systemImage: "sparkles")
                    .font(.title3)
                    .fontWeight(.bold)
                    .padding(.horizontal)

                if isLoadingInsights {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                        .transition(.blurReplace)
                } else {
                    if similarContentEnabled && !similarArticles.isEmpty {
                        similarContentSubsection
                    }

                    if topicsPeopleEnabled && !articleTopics.isEmpty {
                        entityChipsSubsection(
                            titleKey: "SimilarContent.Topics",
                            systemImage: "number",
                            types: ["organization", "place"],
                            names: articleTopics
                        )
                    }

                    if topicsPeopleEnabled && !articlePeople.isEmpty {
                        entityChipsSubsection(
                            titleKey: "SimilarContent.People",
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
        guard similarContentEnabled || topicsPeopleEnabled else { return false }
        return isLoadingInsights || hasAnyInsights
    }

    private var hasAnyInsights: Bool {
        (similarContentEnabled && !similarArticles.isEmpty)
            || (topicsPeopleEnabled && (!articleTopics.isEmpty || !articlePeople.isEmpty))
    }

    @ViewBuilder
    private var similarContentSubsection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("SimilarContent.Title", systemImage: "square.stack.3d.up")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(similarArticles) { item in
                        NavigationLink(value: item.article) {
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
        titleKey: LocalizedStringKey,
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

    /// Kicks off insight loading (similar articles, topics, people) in
    /// the background so it never blocks the UI thread. The SQLite
    /// reads and NLP passes live inside `nonisolated static` helpers
    /// that run on the generic executor (off MainActor); only the
    /// final @State writes land back on MainActor after the awaits.
    func loadInsightsInBackground() {
        guard similarContentEnabled || topicsPeopleEnabled else { return }
        let loadSimilar = similarContentEnabled
        let loadEntities = topicsPeopleEnabled
        let currentArticle = article
        let feedsLookup = feedManager.feedsByID

        isLoadingInsights = true
        Task {
            let loadedSimilar: [SimilarArticleItem]
            if loadSimilar {
                loadedSimilar = await Self.computeSimilarArticles(
                    currentArticle: currentArticle, feedsLookup: feedsLookup
                )
            } else {
                loadedSimilar = []
            }

            let loadedEntities: (topics: [String], people: [String])
            if loadEntities {
                loadedEntities = await Self.computeArticleEntities(
                    articleID: currentArticle.id,
                    articleTitle: currentArticle.title,
                    articleSummary: currentArticle.summary ?? ""
                )
            } else {
                loadedEntities = (topics: [], people: [])
            }

            if loadSimilar {
                similarArticles = loadedSimilar
            }
            if loadEntities {
                articleTopics = loadedEntities.topics
                articlePeople = loadedEntities.people
            }
            isLoadingInsights = false
        }
    }

    /// Runs entity extraction entirely off the main actor. Callable from
    /// a detached task because it takes only Sendable inputs.
    fileprivate nonisolated static func computeArticleEntities(
        articleID: Int64,
        articleTitle: String,
        articleSummary: String
    ) async -> (topics: [String], people: [String]) {
        let db = DatabaseManager.shared
        return await Task.detached(priority: .userInitiated) {
            // Ensure entity extraction has been run for this article.
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

    /// Runs similar-article discovery entirely off the main actor. The
    /// NLP embedding pass, SQLite reads, and cache writes all happen on
    /// a detached utility task; favicons are fetched concurrently after.
    fileprivate nonisolated static func computeSimilarArticles(
        currentArticle: Article,
        feedsLookup: [Int64: Feed]
    ) async -> [SimilarArticleItem] {
        let rawMatches = await Task.detached(priority: .userInitiated) {
            await computeRawMatches(
                currentArticle: currentArticle, feedsLookup: feedsLookup
            )
        }.value

        // Favicons are fetched in parallel — FaviconCache.favicon(for:) is
        // already async and safe to call concurrently.
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
                        sentiment: match.sentiment,
                        favicon: favicon
                    ))
                }
            }
            var results = Array<SimilarArticleItem?>(repeating: nil, count: rawMatches.count)
            for await (index, item) in group {
                results[index] = item
            }
            return results.compactMap { $0 }
        }
    }

    /// Returns match metadata ordered by similarity rank. Uses the SQLite
    /// cache when available; otherwise runs NLP, persists the result, and
    /// marks the source article as computed. Must be called from a
    /// detached task — it is synchronous aside from the NLP await, so
    /// its DB work would otherwise block whichever actor invokes it.
    fileprivate nonisolated static func computeRawMatches(
        currentArticle: Article,
        feedsLookup: [Int64: Feed]
    ) async -> [SimilarMatchData] {
        let db = DatabaseManager.shared

        // 1. Cache hit path — instant return, no NLP, no 48h window scan.
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
            // Empty cache → computed earlier, no matches, skip recompute.
            return []
        }

        // 2. Cache miss — run NLP and persist. The embedding comparison is
        // parallelized inside NLPProcessor.findSimilarArticles.
        guard let candidates = try? db.articlesInWindow(
            around: currentArticle, hours: 48, limit: 60
        ) else {
            try? db.cacheSimilarArticles([], forSourceID: currentArticle.id)
            return []
        }

        let similar = await NLPProcessor.findSimilarArticles(
            to: currentArticle,
            candidates: candidates,
            maxResults: 8,
            maximumDistance: 1.5
        )

        // Persist even if empty so we don't recompute on the next open.
        try? db.cacheSimilarArticles(
            similar.map { (id: $0.articleID, distance: $0.distance) },
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

// Intermediate type so the detached task can return a single value type
// without tripping the large-tuple lint rule.
private struct SimilarMatchData: Sendable {
    let article: Article
    let feedName: String
    let feed: Feed?
    let sentiment: Double?
}

// MARK: - Card

private struct SimilarArticleCard: View {

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.zoomNamespace) private var zoomNamespace
    let item: SimilarArticleItem

    private let cardWidth: CGFloat = 240
    private let imageHeight: CGFloat = 135  // 16:9 widescreen

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

    @ViewBuilder
    private var thumbnailBackground: some View {
        let isDark = colorScheme == .dark
        let bgColor = item.favicon?.cardBackgroundColor(isDarkMode: isDark)
            ?? (isDark ? Color(white: 0.15) : Color(white: 0.9))

        ZStack {
            Rectangle()
                .fill(bgColor)

            if let favicon = item.favicon {
                Image(uiImage: favicon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: imageHeight * 0.5, height: imageHeight * 0.5)
            } else {
                Image(systemName: "doc.text")
                    .font(.system(size: imageHeight * 0.35, weight: .light))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
