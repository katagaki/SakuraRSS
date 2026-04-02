import AppIntents
import SwiftUI
import WidgetKit

// MARK: - App Intent

enum SingleFeedWidgetLayout: String, AppEnum {
    case text
    case thumbnails

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Layout"
    }

    static var caseDisplayRepresentations: [SingleFeedWidgetLayout: DisplayRepresentation] {
        [
            .text: DisplayRepresentation(title: "Text"),
            .thumbnails: DisplayRepresentation(title: "Thumbnails")
        ]
    }
}

struct FeedQuery: EntityQuery {

    func entities(for identifiers: [String]) async throws -> [FeedEntity] {
        let database = DatabaseManager.shared
        let allFeeds = (try? database.allFeeds()) ?? []
        let idSet = Set(identifiers)
        return allFeeds
            .filter { idSet.contains(String($0.id)) }
            .map { FeedEntity(feedID: $0.id, title: $0.title) }
    }

    func suggestedEntities() async throws -> [FeedEntity] {
        let database = DatabaseManager.shared
        let allFeeds = (try? database.allFeeds()) ?? []
        return allFeeds.map { FeedEntity(feedID: $0.id, title: $0.title) }
    }

    func defaultResult() async -> FeedEntity? {
        let database = DatabaseManager.shared
        guard let first = (try? database.allFeeds())?.first else { return nil }
        return FeedEntity(feedID: first.id, title: first.title)
    }
}

struct FeedEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Feed"
    static var defaultQuery = FeedQuery()

    var id: String
    var feedID: Int64
    var title: String

    init(feedID: Int64, title: String) {
        self.id = String(feedID)
        self.feedID = feedID
        self.title = title
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}

struct SingleFeedIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "SingleFeedWidget.IntentTitle"
    static var description: IntentDescription = "SingleFeedWidget.IntentDescription"

    @Parameter(title: "Feed")
    var feed: FeedEntity?

    @Parameter(title: "Layout", default: .thumbnails)
    var layout: SingleFeedWidgetLayout?
}

// MARK: - Timeline Entry

struct SingleFeedArticle: Identifiable {
    let id: Int64
    let title: String
    let imageData: Data?
    let publishedDate: Date?
}

struct SingleFeedEntry: TimelineEntry {
    let date: Date
    let feedTitle: String
    let articles: [SingleFeedArticle]
    let layout: SingleFeedWidgetLayout
}

// MARK: - Provider

struct SingleFeedProvider: AppIntentTimelineProvider {

    func placeholder(in _: Context) -> SingleFeedEntry {
        SingleFeedEntry(
            date: Date(),
            feedTitle: "Feed",
            articles: [
                SingleFeedArticle(id: 0, title: "Loading...", imageData: nil, publishedDate: Date())
            ],
            layout: .thumbnails
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
                feedTitle: "",
                articles: [],
                layout: layout
            )
        }

        let feedID = feed.feedID

        do {
            let feedTitle = (try database.feed(byID: feedID))?.title ?? feed.title
            let articleLimit = layout == .text ? 9 : 4
            let dbArticles = try database.articles(forFeedID: feedID, limit: articleLimit)

            var widgetArticles: [SingleFeedArticle] = []
            for article in dbArticles {
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
                feedTitle: feedTitle,
                articles: widgetArticles,
                layout: layout
            )
        } catch {
            return SingleFeedEntry(
                date: Date(),
                feedTitle: feed.title,
                articles: [],
                layout: layout
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
        let resized = renderer.jpegData(withCompressionQuality: 0.7) { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized
    }
}

// MARK: - Small Widget View

struct SingleFeedSmallView: View {

    let entry: SingleFeedEntry

    var body: some View {
        if let article = entry.articles.first {
            ZStack(alignment: .bottomLeading) {
                if let imageData = article.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    LinearGradient(
                        colors: [Color("AccentColor").opacity(0.6), Color("AccentColor")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }

                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.feedTitle)
                        .font(.system(size: 10, weight: .medium, design: .default).width(.condensed))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                    Text(article.title)
                        .font(.system(size: 12, weight: .semibold, design: .default).width(.condensed))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }
                .padding(12)
            }
            .widgetURL(URL(string: "sakura://article/\(article.id)")!)
        } else {
            VStack(spacing: 4) {
                Image(systemName: "newspaper")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
                Text("Widget.NoArticles")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Thumbnail Grid Views

struct SingleFeedThumbnailCell: View {

    let article: SingleFeedArticle
    let feedTitle: String

    var body: some View {
        Link(destination: URL(string: "sakura://article/\(article.id)")!) {
            GeometryReader { geo in
                ZStack(alignment: .bottomLeading) {
                    if let imageData = article.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color("AccentColor").opacity(0.3))
                            .overlay {
                                Image(systemName: "newspaper")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.secondary)
                            }
                    }

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.75)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geo.size.height * 0.5)
                    .frame(maxHeight: .infinity, alignment: .bottom)

                    Text(article.title)
                        .font(.system(size: 14, weight: .semibold, design: .default).width(.condensed))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .padding(10)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct SingleFeedMediumThumbnailsView: View {

    let entry: SingleFeedEntry

    var body: some View {
        if entry.articles.isEmpty {
            emptyView(iconSize: 22, textSize: 12)
        } else {
            let items = Array(entry.articles.prefix(2))
            HStack(spacing: 8) {
                ForEach(items) { article in
                    SingleFeedThumbnailCell(article: article, feedTitle: entry.feedTitle)
                }
            }
        }
    }
}

struct SingleFeedLargeThumbnailsView: View {

    let entry: SingleFeedEntry

    var body: some View {
        if entry.articles.isEmpty {
            emptyView(iconSize: 34, textSize: 15)
        } else {
            let items = Array(entry.articles.prefix(4))
            let topRow = Array(items.prefix(2))
            let bottomRow = Array(items.dropFirst(2))

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    ForEach(topRow) { article in
                        SingleFeedThumbnailCell(article: article, feedTitle: entry.feedTitle)
                    }
                }
                if !bottomRow.isEmpty {
                    HStack(spacing: 10) {
                        ForEach(bottomRow) { article in
                            SingleFeedThumbnailCell(article: article, feedTitle: entry.feedTitle)
                        }
                        if bottomRow.count < 2 {
                            Color.clear
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Text Views

struct SingleFeedMediumTextView: View {

    let entry: SingleFeedEntry

    var body: some View {
        if entry.articles.isEmpty {
            emptyView(iconSize: 22, textSize: 12)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(entry.articles.prefix(4)) { article in
                    Link(destination: URL(string: "sakura://article/\(article.id)")!) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(article.title)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            if let date = article.publishedDate {
                                Text(date, style: .relative)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if article.id != entry.articles.prefix(4).last?.id {
                        Divider()
                    }
                }
            }
        }
    }
}

struct SingleFeedLargeTextView: View {

    let entry: SingleFeedEntry

    var body: some View {
        if entry.articles.isEmpty {
            emptyView(iconSize: 34, textSize: 15)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(entry.articles.prefix(9)) { article in
                    Link(destination: URL(string: "sakura://article/\(article.id)")!) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(article.title)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(2)
                            if let date = article.publishedDate {
                                Text(date, style: .relative)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if article.id != entry.articles.prefix(9).last?.id {
                        Divider()
                    }
                }
            }
        }
    }
}

// MARK: - Empty View Helper

private func emptyView(iconSize: CGFloat, textSize: CGFloat) -> some View {
    VStack(spacing: iconSize > 30 ? 8 : 4) {
        Image(systemName: "newspaper")
            .font(.system(size: iconSize))
            .foregroundStyle(.secondary)
        Text("Widget.NoArticles")
            .font(.system(size: textSize))
            .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}

// MARK: - Main Widget View

struct SingleFeedWidgetView: View {

    @Environment(\.widgetFamily) var family
    var entry: SingleFeedEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SingleFeedSmallView(entry: entry)
        case .systemMedium:
            if entry.layout == .thumbnails {
                SingleFeedMediumThumbnailsView(entry: entry)
                    .padding(16)
            } else {
                SingleFeedMediumTextView(entry: entry)
                    .padding(16)
            }
        case .systemLarge:
            if entry.layout == .thumbnails {
                SingleFeedLargeThumbnailsView(entry: entry)
                    .padding(16)
            } else {
                SingleFeedLargeTextView(entry: entry)
                    .padding(16)
            }
        default:
            SingleFeedSmallView(entry: entry)
        }
    }
}

// MARK: - Widget Definition

struct SingleFeedWidget: Widget {
    let kind = "SingleFeedWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SingleFeedIntent.self,
            provider: SingleFeedProvider()
        ) { entry in
            SingleFeedWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color("WidgetBackground")
                }
        }
        .contentMarginsDisabled()
        .configurationDisplayName(String(localized: "SingleFeedWidget.DisplayName"))
        .description(String(localized: "SingleFeedWidget.Description"))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
