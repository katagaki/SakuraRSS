import SwiftUI
import WidgetKit

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
            return SingleFeedEntry(
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

        let feedID = feed.feedID
        let defaults = UserDefaults(suiteName: "group.com.tsubuzaki.SakuraRSS")
        let storedPage = defaults?.integer(forKey: "singleFeedPage_\(feedID)") ?? 0

        do {
            let feedTitle = (try database.feed(byID: feedID))?.title ?? feed.title
            let perPage = layout == .text ? 9 : columns * columns
            let maxPages = 3
            let totalLimit = perPage * maxPages
            let dbArticles = try database.articles(forFeedID: feedID, limit: totalLimit)

            let totalPages = max(1, Int(ceil(Double(dbArticles.count) / Double(perPage))))
            let currentPage = min(storedPage, totalPages - 1)
            let pageStart = currentPage * perPage
            let pageArticles = Array(dbArticles.dropFirst(pageStart).prefix(perPage))

            // Skip network fetches when article set is unchanged, to avoid retrying failed downloads each wake.
            let articleIDsMarker = pageArticles.map(\.id).map(String.init).joined(separator: ",")
            let markerKey = "singleFeedMarker_\(feedID)_\(layout.rawValue)_\(columns)_\(currentPage)"
            let previousMarker = defaults?.string(forKey: markerKey)
            let articleSetUnchanged = previousMarker == articleIDsMarker
            defaults?.set(articleIDsMarker, forKey: markerKey)

            let thumbnailCache = WidgetThumbnailCache(
                scope: "single_\(feedID)_\(layout.rawValue)_\(columns)"
            )

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

            return SingleFeedEntry(
                date: Date(),
                feedID: feedID,
                feedTitle: feedTitle,
                articles: widgetArticles,
                layout: layout,
                columns: columns,
                currentPage: currentPage,
                totalPages: totalPages
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
