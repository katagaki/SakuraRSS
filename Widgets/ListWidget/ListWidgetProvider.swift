import SwiftUI
import WidgetKit
import Hanami

struct ListWidgetProvider: AppIntentTimelineProvider {

    func placeholder(in _: Context) -> ListWidgetEntry {
        let placeholderArticles = (0..<9).map { index in
            ListWidgetArticle(
                id: Int64(index),
                title: String(localized: "Placeholder.Loading", table: "Widget"),
                imageData: nil,
                publishedDate: Date()
            )
        }
        return ListWidgetEntry(
            date: Date(),
            listID: 0,
            listTitle: String(localized: "Placeholder.Feed", table: "Widget"),
            articles: placeholderArticles,
            layout: .thumbnails,
            columns: 3,
            currentPage: 0,
            totalPages: 1
        )
    }

    func snapshot(for configuration: ListWidgetIntent, in context: Context) async -> ListWidgetEntry {
        await loadEntry(for: configuration, family: context.family)
    }

    func timeline(for configuration: ListWidgetIntent, in context: Context) async -> Timeline<ListWidgetEntry> {
        let entry = await loadEntry(for: configuration, family: context.family)
        // 90-minute interval; widget reloads wake the app process.
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(90 * 60)))
    }

    private func loadEntry(
        for configuration: ListWidgetIntent, family: WidgetFamily
    ) async -> ListWidgetEntry {
        let database = DatabaseManager.shared
        let layout = configuration.layout ?? .thumbnails
        let columns = (configuration.columns ?? .three).rawValue

        guard let listEntity = configuration.list else {
            return Self.emptyListWidgetEntry(listID: 0, listTitle: "", layout: layout, columns: columns)
        }

        let listID = listEntity.listID
        let defaults = UserDefaults(suiteName: "group.com.tsubuzaki.SakuraRSS")
        let storedPage = defaults?.integer(forKey: "listWidgetPage_\(listID)") ?? 0

        do {
            return try await loadListEntry(
                listEntity: listEntity,
                params: ListWidgetLoadParams(
                    listID: listID,
                    layout: layout,
                    columns: columns,
                    storedPage: storedPage,
                    thumbnailMaxPixelSize: Self.thumbnailMaxPixelSize(for: family)
                ),
                defaults: defaults,
                database: database
            )
        } catch {
            return Self.emptyListWidgetEntry(
                listID: listID, listTitle: listEntity.title, layout: layout, columns: columns
            )
        }
    }

    private func loadListEntry(
        listEntity: ListEntity,
        params: ListWidgetLoadParams,
        defaults: UserDefaults?,
        database: DatabaseManager
    ) async throws -> ListWidgetEntry {
        let listID = params.listID
        let listTitle = (try database.list(byID: listID))?.name ?? listEntity.title
        let feedIDs = try database.feedIDs(forListID: listID)
        guard !feedIDs.isEmpty else {
            return Self.emptyListWidgetEntry(
                listID: listID, listTitle: listTitle,
                layout: params.layout, columns: params.columns
            )
        }

        let perPage = params.layout == .text ? 9 : params.columns * params.columns
        let totalLimit = perPage * 3
        let dbArticles = try database.articlesList(forFeedIDs: feedIDs, limit: totalLimit)
        let totalPages = max(1, Int(ceil(Double(dbArticles.count) / Double(perPage))))
        let currentPage = min(params.storedPage, totalPages - 1)
        let pageStart = currentPage * perPage
        let pageArticles = Array(dbArticles.dropFirst(pageStart).prefix(perPage))

        let widgetArticles = await loadWidgetArticles(
            pageArticles: pageArticles,
            request: ListWidgetRequest(
                listID: listID,
                layout: params.layout,
                columns: params.columns,
                currentPage: currentPage,
                thumbnailMaxPixelSize: params.thumbnailMaxPixelSize
            ),
            defaults: defaults,
            database: database
        )

        return ListWidgetEntry(
            date: Date(),
            listID: listID,
            listTitle: listTitle,
            articles: widgetArticles,
            layout: params.layout,
            columns: params.columns,
            currentPage: currentPage,
            totalPages: totalPages
        )
    }

    private static func emptyListWidgetEntry(
        listID: Int64, listTitle: String, layout: SingleFeedWidgetLayout, columns: Int
    ) -> ListWidgetEntry {
        ListWidgetEntry(
            date: Date(),
            listID: listID,
            listTitle: listTitle,
            articles: [],
            layout: layout,
            columns: columns,
            currentPage: 0,
            totalPages: 1
        )
    }

    private func loadWidgetArticles(
        pageArticles: [Article],
        request: ListWidgetRequest,
        defaults: UserDefaults?,
        database: DatabaseManager
    ) async -> [ListWidgetArticle] {
        // Skip network fetches when article set is unchanged, to avoid retrying failed downloads each wake.
        let articleIDsMarker = pageArticles.map(\.id).map(String.init).joined(separator: ",")
        let markerKey = request.markerKey
        let previousMarker = defaults?.string(forKey: markerKey)
        let articleSetUnchanged = previousMarker == articleIDsMarker
        defaults?.set(articleIDsMarker, forKey: markerKey)

        let thumbnailCache = WidgetThumbnailCache(scope: request.cacheScope)
        let resolveContext = ThumbnailResolveContext(
            articleSetUnchanged: articleSetUnchanged,
            thumbnailCache: thumbnailCache,
            database: database,
            maxPixelSize: request.thumbnailMaxPixelSize
        )

        var widgetArticles: [ListWidgetArticle] = []
        for article in pageArticles {
            let imageData = await resolveImageData(
                urlString: article.imageURL,
                articleID: article.id,
                context: resolveContext
            )
            widgetArticles.append(ListWidgetArticle(
                id: article.id,
                title: article.title,
                imageData: imageData,
                publishedDate: article.publishedDate
            ))
        }
        thumbnailCache.prune(keeping: pageArticles.map(\.id))
        return widgetArticles
    }

    private struct ThumbnailResolveContext {
        let articleSetUnchanged: Bool
        let thumbnailCache: WidgetThumbnailCache
        let database: DatabaseManager
        let maxPixelSize: CGFloat
    }

    private func resolveImageData(
        urlString: String?,
        articleID: Int64,
        context: ThumbnailResolveContext
    ) async -> Data? {
        let articleSetUnchanged = context.articleSetUnchanged
        let thumbnailCache = context.thumbnailCache
        let database = context.database
        guard let urlString, let imageURL = URL(string: urlString) else { return nil }
        if articleSetUnchanged, let cached = thumbnailCache.thumbnail(for: articleID) {
            return cached
        }
        var rawData: Data?
        if let cached = try? database.cachedImageData(for: urlString) {
            rawData = cached
        } else if !articleSetUnchanged {
            if let (data, _) = try? await URLSession.shared.data(for: .sakuraImage(url: imageURL)) {
                try? database.cacheImageData(data, for: urlString)
                rawData = data
            }
        }
        guard let rawData else { return nil }
        let imageData = await Self.downsampleImageData(rawData, maxDimension: context.maxPixelSize)
        if let imageData {
            thumbnailCache.storeThumbnail(imageData, for: articleID)
        }
        return imageData
    }

    private static let thumbnailMaxPixelSize: CGFloat = 240
    private static let smallWidgetThumbnailMaxPixelSize: CGFloat = 300

    private static func thumbnailMaxPixelSize(for family: WidgetFamily) -> CGFloat {
        family == .systemSmall ? smallWidgetThumbnailMaxPixelSize : thumbnailMaxPixelSize
    }

    private static func downsampleImageData(_ data: Data, maxDimension: CGFloat) async -> Data? {
        ImageDownsampler.downsampleToJPEG(data, maxPixelSize: maxDimension, cacheImmediately: false)
    }
}
