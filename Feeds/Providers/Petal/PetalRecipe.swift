import Foundation

/// A user-defined recipe that turns a webpage into a feed.
nonisolated struct PetalRecipe: Codable, Sendable, Hashable {

    static let currentVersion = 1

    var version: Int = PetalRecipe.currentVersion

    let id: UUID

    var name: String

    var siteURL: String

    var fetchMode: FetchMode = .staticHTML

    var itemSelector: String

    var titleSelector: String?

    var linkSelector: String?

    var linkAttribute: String = "href"

    var summarySelector: String?

    var imageSelector: String?

    var imageAttribute: String = "src"

    var dateSelector: String?

    var dateAttribute: String?

    var authorSelector: String?

    var baseURL: String?

    var maxItems: Int = 50

    var lastModified: Date = Date()

    init(
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

    enum FetchMode: String, Codable, Sendable, CaseIterable {
        case staticHTML
        case rendered
    }

    var feedURL: String { "petal://\(siteURL)" }

    static func isPetalFeedURL(_ url: String) -> Bool {
        url.hasPrefix("petal://")
    }

    static func siteURL(from feedURL: String) -> String? {
        guard feedURL.hasPrefix("petal://") else { return nil }
        return String(feedURL.dropFirst("petal://".count))
    }
}
