import SwiftUI
import WidgetKit

struct ListWidgetProvider: AppIntentTimelineProvider {

    func placeholder(in _: Context) -> ListWidgetEntry {
        let placeholderArticles = (0..<9).map { index in
            ListWidgetArticle(
                id: Int64(index),
                title: String(localized: "Widget.Placeholder.Loading"),
                imageData: nil,
                publishedDate: Date()
            )
        }
        return ListWidgetEntry(
            date: Date(),
            listID: 0,
            listTitle: String(localized: "Widget.Placeholder.Feed"),
            articles: placeholderArticles,
            layout: .thumbnails,
            columns: 3,
            currentPage: 0,
            totalPages: 1
        )
    }

    func snapshot(for configuration: ListWidgetIntent, in _: Context) async -> ListWidgetEntry {
        await loadEntry(for: configuration)
    }

    func timeline(for configuration: ListWidgetIntent, in _: Context) async -> Timeline<ListWidgetEntry> {
        let entry = await loadEntry(for: configuration)
        // Timeline refreshes every 90 minutes instead of every 30.  Widgets
        // running outside the app process wake it on every reload; tripling
        // the interval triples the battery savings for this path.
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(90 * 60)))
    }

    private func loadEntry(for configuration: ListWidgetIntent) async -> ListWidgetEntry {
        let database = DatabaseManager.shared
        let layout = configuration.layout ?? .thumbnails
        let columns = (configuration.columns ?? .three).rawValue

        guard let listEntity = configuration.list else {
            return ListWidgetEntry(
                date: Date(),
                listID: 0,
                listTitle: "",
                articles: [],
                layout: layout,
                columns: columns,
                currentPage: 0,
                totalPages: 1
            )
        }

        let listID = listEntity.listID
        let defaults = UserDefaults(suiteName: "group.com.tsubuzaki.SakuraRSS")
        let storedPage = defaults?.integer(forKey: "listWidgetPage_\(listID)") ?? 0

        do {
            let listTitle = (try database.list(byID: listID))?.name ?? listEntity.title
            let feedIDs = try database.feedIDs(forListID: listID)
            guard !feedIDs.isEmpty else {
                return ListWidgetEntry(
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

            let perPage = layout == .text ? 9 : columns * columns
            let maxPages = 3
            let totalLimit = perPage * maxPages

            // Collect articles from all feeds in the list
            var dbArticles: [Article] = []
            for feedID in feedIDs {
                let feedArticles = try database.articles(forFeedID: feedID, limit: totalLimit)
                dbArticles.append(contentsOf: feedArticles)
            }
            // Sort by date descending and limit
            dbArticles.sort { ($0.publishedDate ?? .distantPast) > ($1.publishedDate ?? .distantPast) }
            dbArticles = Array(dbArticles.prefix(totalLimit))

            let totalPages = max(1, Int(ceil(Double(dbArticles.count) / Double(perPage))))
            let currentPage = min(storedPage, totalPages - 1)
            let pageStart = currentPage * perPage
            let pageArticles = Array(dbArticles.dropFirst(pageStart).prefix(perPage))

            // Skip image network fetches when the top article IDs haven't
            // changed since the last timeline build.  DB-cached images still
            // resolve normally; this prevents retrying failing downloads on
            // every 90-minute timeline wake.
            let articleIDsMarker = pageArticles.map(\.id).map(String.init).joined(separator: ",")
            let markerKey = "listWidgetMarker_\(listID)_\(layout.rawValue)_\(columns)_\(currentPage)"
            let previousMarker = defaults?.string(forKey: markerKey)
            let articleSetUnchanged = previousMarker == articleIDsMarker
            defaults?.set(articleIDsMarker, forKey: markerKey)

            var widgetArticles: [ListWidgetArticle] = []
            for article in pageArticles {
                var imageData: Data?
                if let imageURLString = article.imageURL, let imageURL = URL(string: imageURLString) {
                    var rawData: Data?
                    if let cached = try? database.cachedImageData(for: imageURLString) {
                        rawData = cached
                    } else if !articleSetUnchanged {
                        if let (data, _) = try? await URLSession.shared.data(for: .sakura(url: imageURL)) {
                            try? database.cacheImageData(data, for: imageURLString)
                            rawData = data
                        }
                    }
                    if let rawData {
                        imageData = await Self.downsampleImageData(rawData, maxDimension: 300)
                    }
                }
                widgetArticles.append(ListWidgetArticle(
                    id: article.id,
                    title: article.title,
                    imageData: imageData,
                    publishedDate: article.publishedDate
                ))
            }

            return ListWidgetEntry(
                date: Date(),
                listID: listID,
                listTitle: listTitle,
                articles: widgetArticles,
                layout: layout,
                columns: columns,
                currentPage: currentPage,
                totalPages: totalPages
            )
        } catch {
            return ListWidgetEntry(
                date: Date(),
                listID: listID,
                listTitle: listEntity.title,
                articles: [],
                layout: layout,
                columns: columns,
                currentPage: 0,
                totalPages: 1
            )
        }
    }

    private static func downsampleImageData(_ data: Data, maxDimension: CGFloat) async -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let size = image.size

        let scale: CGFloat = size.width > size.height
            ? maxDimension / size.width
            : maxDimension / size.height
        let targetSize = CGSize(
            width: round(size.width * min(scale, 1.0)),
            height: round(size.height * min(scale, 1.0))
        )

        guard let thumbnail = await image.byPreparingThumbnail(ofSize: targetSize) else { return nil }
        return thumbnail.jpegData(compressionQuality: 0.7)
    }
}
