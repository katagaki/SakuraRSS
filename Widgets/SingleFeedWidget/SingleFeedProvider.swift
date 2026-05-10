import SwiftUI
import WidgetKit
import Hanami

struct SingleFeedProvider: AppIntentTimelineProvider {

    func placeholder(in _: Context) -> SingleFeedEntry {
        let placeholderArticles = (0..<9).map { index in
            SingleFeedArticle(
                id: Int64(index),
                title: String(localized: "Placeholder.Loading", table: "Widget"),
                imageData: nil,
                publishedDate: Date()
            )
        }
        return SingleFeedEntry(
            date: Date(),
            feedID: 0,
            feedTitle: String(localized: "Placeholder.Feed", table: "Widget"),
            articles: placeholderArticles,
            layout: .thumbnails,
            columns: 3,
            currentPage: 0,
            totalPages: 1
        )
    }

    func snapshot(for configuration: SingleFeedIntent, in _: Context) async -> SingleFeedEntry {
        await loadEntry(for: configuration)
    }

    func timeline(for configuration: SingleFeedIntent, in _: Context) async -> Timeline<SingleFeedEntry> {
        let entry = await loadEntry(for: configuration)
        // 90-minute interval; widget reloads wake the app process.
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(90 * 60)))
    }

    private func loadEntry(for configuration: SingleFeedIntent) async -> SingleFeedEntry {
        let database = DatabaseManager.shared
        let layout = configuration.layout ?? .thumbnails
        let columns = (configuration.columns ?? .three).rawValue

        guard let feed = configuration.feed else {
            return Self.emptySingleFeedEntry(layout: layout, columns: columns)
        }

        let feedID = feed.feedID
        let defaults = UserDefaults(suiteName: "group.com.tsubuzaki.SakuraRSS")
        let storedPage = defaults?.integer(forKey: "singleFeedPage_\(feedID)") ?? 0

        do {
            return try await loadFeedEntry(
                feed: feed,
                params: SingleFeedLoadParams(
                    feedID: feedID,
                    layout: layout,
                    columns: columns,
                    storedPage: storedPage
                ),
                defaults: defaults,
                database: database
            )
        } catch {
            return SingleFeedEntry(
                date: Date(),
                feedID: feedID,
                feedTitle: feed.title,
                articles: [],
                layout: layout,
                columns: columns,
                currentPage: 0,
                totalPages: 1
            )
        }
    }

    private func loadFeedEntry(
        feed: FeedEntity,
        params: SingleFeedLoadParams,
        defaults: UserDefaults?,
        database: DatabaseManager
    ) async throws -> SingleFeedEntry {
        let feedTitle = (try database.feed(byID: params.feedID))?.title ?? feed.title
        let perPage = params.layout == .text ? 9 : params.columns * params.columns
        let totalLimit = perPage * 3
        let dbArticles = try database.articles(forFeedID: params.feedID, limit: totalLimit)
        let totalPages = max(1, Int(ceil(Double(dbArticles.count) / Double(perPage))))
        let currentPage = min(params.storedPage, totalPages - 1)
        let pageStart = currentPage * perPage
        let pageArticles = Array(dbArticles.dropFirst(pageStart).prefix(perPage))

        let widgetArticles = await loadWidgetArticles(
            pageArticles: pageArticles,
            request: SingleFeedWidgetRequest(
                feedID: params.feedID,
                layout: params.layout,
                columns: params.columns,
                currentPage: currentPage
            ),
            defaults: defaults,
            database: database
        )

        return SingleFeedEntry(
            date: Date(),
            feedID: params.feedID,
            feedTitle: feedTitle,
            articles: widgetArticles,
            layout: params.layout,
            columns: params.columns,
            currentPage: currentPage,
            totalPages: totalPages
        )
    }

    private static func emptySingleFeedEntry(
        layout: SingleFeedWidgetLayout, columns: Int
    ) -> SingleFeedEntry {
        SingleFeedEntry(
            date: Date(),
            feedID: 0,
            feedTitle: "",
            articles: [],
            layout: layout,
            columns: columns,
            currentPage: 0,
            totalPages: 1
        )
    }

    private func loadWidgetArticles(
        pageArticles: [Article],
        request: SingleFeedWidgetRequest,
        defaults: UserDefaults?,
        database: DatabaseManager
    ) async -> [SingleFeedArticle] {
        // Skip network fetches when article set is unchanged, to avoid retrying failed downloads each wake.
        let articleIDsMarker = pageArticles.map(\.id).map(String.init).joined(separator: ",")
        let markerKey = request.markerKey
        let previousMarker = defaults?.string(forKey: markerKey)
        let articleSetUnchanged = previousMarker == articleIDsMarker
        defaults?.set(articleIDsMarker, forKey: markerKey)

        let thumbnailCache = WidgetThumbnailCache(scope: request.cacheScope)

        var widgetArticles: [SingleFeedArticle] = []
        for article in pageArticles {
            let imageData = await resolveImageData(
                urlString: article.imageURL,
                articleID: article.id,
                articleSetUnchanged: articleSetUnchanged,
                thumbnailCache: thumbnailCache,
                database: database
            )
            widgetArticles.append(SingleFeedArticle(
                id: article.id,
                title: article.title,
                imageData: imageData,
                publishedDate: article.publishedDate
            ))
        }
        thumbnailCache.prune(keeping: pageArticles.map(\.id))
        return widgetArticles
    }

    private func resolveImageData(
        urlString: String?,
        articleID: Int64,
        articleSetUnchanged: Bool,
        thumbnailCache: WidgetThumbnailCache,
        database: DatabaseManager
    ) async -> Data? {
        guard let urlString, let imageURL = URL(string: urlString) else { return nil }
        if articleSetUnchanged, let cached = thumbnailCache.thumbnail(for: articleID) {
            return cached
        }
        var rawData: Data?
        if let cached = try? database.cachedImageData(for: urlString) {
            log("Widget", "Image cache hit for \(urlString) (\(cached.count) bytes)")
            rawData = cached
        } else if !articleSetUnchanged {
            if let (data, _) = try? await URLSession.shared.data(for: .sakuraImage(url: imageURL)) {
                log("Widget", "Downloaded image \(urlString) (\(data.count) bytes)")
                try? database.cacheImageData(data, for: urlString)
                rawData = data
            } else {
                log("Widget", "Failed to download image \(urlString)")
            }
        }
        guard let rawData else { return nil }
        let imageData = await Self.downsampleImageData(rawData, maxDimension: 300)
        if let imageData {
            thumbnailCache.storeThumbnail(imageData, for: articleID)
        }
        if imageData == nil {
            log("Widget", "Failed to downsample image \(urlString)")
        }
        return imageData
    }

    private static func downsampleImageData(_ data: Data, maxDimension: CGFloat) async -> Data? {
        ImageDownsampler.downsampleToJPEG(data, maxPixelSize: maxDimension)
    }
}
