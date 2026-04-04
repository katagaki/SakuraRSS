import SwiftUI
import WidgetKit

struct SingleFeedProvider: AppIntentTimelineProvider {

    func placeholder(in _: Context) -> SingleFeedEntry {
        SingleFeedEntry(
            date: Date(),
            feedID: 0,
            feedTitle: String(localized: "Widget.Placeholder.Feed"),
            articles: [
                SingleFeedArticle(id: 0, title: String(localized: "Widget.Placeholder.Loading"), imageData: nil, publishedDate: Date())
            ],
            layout: .thumbnails,
            currentPage: 0,
            totalPages: 1
        )
    }

    func snapshot(for configuration: SingleFeedIntent, in _: Context) async -> SingleFeedEntry {
        await loadEntry(for: configuration)
    }

    func timeline(for configuration: SingleFeedIntent, in _: Context) async -> Timeline<SingleFeedEntry> {
        let entry = await loadEntry(for: configuration)
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60)))
    }

    private func loadEntry(for configuration: SingleFeedIntent) async -> SingleFeedEntry {
        let database = DatabaseManager.shared
        let layout = configuration.layout ?? .thumbnails

        guard let feed = configuration.feed else {
            return SingleFeedEntry(
                date: Date(),
                feedID: 0,
                feedTitle: "",
                articles: [],
                layout: layout,
                currentPage: 0,
                totalPages: 1
            )
        }

        let feedID = feed.feedID
        let defaults = UserDefaults(suiteName: "group.com.tsubuzaki.SakuraRSS")
        let storedPage = defaults?.integer(forKey: "singleFeedPage_\(feedID)") ?? 0

        do {
            let feedTitle = (try database.feed(byID: feedID))?.title ?? feed.title
            let perPage = layout == .text ? 9 : 4
            let maxPages = 3
            let totalLimit = perPage * maxPages
            let dbArticles = try database.articles(forFeedID: feedID, limit: totalLimit)

            let totalPages = max(1, Int(ceil(Double(dbArticles.count) / Double(perPage))))
            let currentPage = min(storedPage, totalPages - 1)
            let pageStart = currentPage * perPage
            let pageArticles = Array(dbArticles.dropFirst(pageStart).prefix(perPage))

            var widgetArticles: [SingleFeedArticle] = []
            for article in pageArticles {
                var imageData: Data?
                if let imageURLString = article.imageURL, let imageURL = URL(string: imageURLString) {
                    var rawData: Data?
                    if let cached = try? database.cachedImageData(for: imageURLString) {
                        rawData = cached
                    } else {
                        if let (data, _) = try? await URLSession.shared.data(from: imageURL) {
                            try? database.cacheImageData(data, for: imageURLString)
                            rawData = data
                        }
                    }
                    if let rawData {
                        imageData = Self.downsampleImageData(rawData, maxDimension: 400)
                    }
                }
                widgetArticles.append(SingleFeedArticle(
                    id: article.id,
                    title: article.title,
                    imageData: imageData,
                    publishedDate: article.publishedDate
                ))
            }

            return SingleFeedEntry(
                date: Date(),
                feedID: feedID,
                feedTitle: feedTitle,
                articles: widgetArticles,
                layout: layout,
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
                currentPage: 0,
                totalPages: 1
            )
        }
    }

    private static func downsampleImageData(_ data: Data, maxDimension: CGFloat) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else { return data }

        let scale: CGFloat
        if size.width > size.height {
            scale = maxDimension / size.width
        } else {
            scale = maxDimension / size.height
        }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.jpegData(withCompressionQuality: 0.7) { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized
    }
}
