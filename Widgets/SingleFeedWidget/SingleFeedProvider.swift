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
        // Timeline refreshes every 90 minutes instead of every 30.  Widgets
        // running outside the app process wake it on every reload; tripling
        // the interval triples the battery savings for this path.
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

            // Skip image network fetches when the top article IDs haven't
            // changed since the last timeline build.  DB-cached images still
            // resolve normally; this prevents retrying failing downloads on
            // every 90-minute timeline wake.
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
                var imageData: Data?
                if let imageURLString = article.imageURL, let imageURL = URL(string: imageURLString) {
                    if articleSetUnchanged,
                       let cachedThumb = thumbnailCache.thumbnail(for: article.id) {
                        imageData = cachedThumb
                    } else {
                        var rawData: Data?
                        if let cached = try? database.cachedImageData(for: imageURLString) {
                            #if DEBUG
                            debugPrint("[Widget] Image cache hit for \(imageURLString) (\(cached.count) bytes)")
                            #endif
                            rawData = cached
                        } else if !articleSetUnchanged {
                            if let (data, _) = try? await URLSession.shared.data(for: .sakura(url: imageURL)) {
                                #if DEBUG
                                debugPrint("[Widget] Downloaded image \(imageURLString) (\(data.count) bytes)")
                                #endif
                                try? database.cacheImageData(data, for: imageURLString)
                                rawData = data
                            } else {
                                #if DEBUG
                                debugPrint("[Widget] Failed to download image \(imageURLString)")
                                #endif
                            }
                        }
                        if let rawData {
                            imageData = await Self.downsampleImageData(rawData, maxDimension: 300)
                            if let imageData {
                                thumbnailCache.storeThumbnail(imageData, for: article.id)
                            }
                            #if DEBUG
                            if imageData == nil {
                                debugPrint("[Widget] Failed to downsample image \(imageURLString)")
                            }
                            #endif
                        }
                    }
                }
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

    private static func downsampleImageData(_ data: Data, maxDimension: CGFloat) async -> Data? {
        ImageDownsampler.downsampleToJPEG(data, maxPixelSize: maxDimension)
    }
}
