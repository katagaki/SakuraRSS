import Foundation

/// A user-defined recipe that turns a webpage into a feed.
public nonisolated struct PetalRecipe: Codable, Sendable, Hashable {

    public static let currentVersion = 1

    public var version: Int = PetalRecipe.currentVersion

    public let id: UUID

    public var name: String

    public var siteURL: String

    public var fetchMode: FetchMode = .staticHTML

    public var itemSelector: String

    public var titleSelector: String?

    public var linkSelector: String?

    public var linkAttribute: String = "href"

    public var summarySelector: String?

    public var imageSelector: String?

    public var imageAttribute: String = "src"

    public var dateSelector: String?

    public var dateAttribute: String?

    public var authorSelector: String?

    public var baseURL: String?

    public var maxItems: Int = 50

    public var lastModified: Date = Date()

    public init(
        id: UUID = UUID(),
        name: String,
        siteURL: String,
        fetchMode: FetchMode = .staticHTML,
        itemSelector: String,
        titleSelector: String? = nil,
        linkSelector: String? = nil,
        linkAttribute: String = "href",
        summarySelector: String? = nil,
        imageSelector: String? = nil,
        imageAttribute: String = "src",
        dateSelector: String? = nil,
        dateAttribute: String? = nil,
        authorSelector: String? = nil,
        baseURL: String? = nil,
        maxItems: Int = 50
    ) {
        self.id = id
        self.name = name
        self.siteURL = siteURL
        self.fetchMode = fetchMode
        self.itemSelector = itemSelector
        self.titleSelector = titleSelector
        self.linkSelector = linkSelector
        self.linkAttribute = linkAttribute
        self.summarySelector = summarySelector
        self.imageSelector = imageSelector
        self.imageAttribute = imageAttribute
        self.dateSelector = dateSelector
        self.dateAttribute = dateAttribute
        self.authorSelector = authorSelector
        self.baseURL = baseURL
        self.maxItems = maxItems
    }

    public enum FetchMode: String, Codable, Sendable, CaseIterable {
        case staticHTML
        case rendered
    }

    public var feedURL: String { "petal://\(siteURL)" }

    public static func isPetalFeedURL(_ url: String) -> Bool {
        url.hasPrefix("petal://")
    }

    public static func siteURL(from feedURL: String) -> String? {
        guard feedURL.hasPrefix("petal://") else { return nil }
        return String(feedURL.dropFirst("petal://".count))
    }
}
