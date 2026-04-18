import Foundation

/// A user-defined recipe that turns a webpage into a feed.
///
/// Petals ship alongside the regular RSS/Atom plumbing: the feed's
/// `url` is rewritten to `petal://<siteURL>` so `refreshFeed`
/// dispatches to `PetalEngine` instead of `RSSParser`, mirroring the
/// pattern already used for X / Instagram / YouTube pseudo-feeds.
///
/// Recipes are portable: exporting a Petal writes a `.srss` package
/// (ZIP) containing the encoded recipe, an optional feed icon, and a
/// small metadata blob identifying the app version that created it.
nonisolated struct PetalRecipe: Codable, Sendable, Hashable {

    /// Recipe format version. Bump when the decoder can no longer
    /// read older payloads so imports can fail gracefully.
    static let currentVersion = 1

    var version: Int = PetalRecipe.currentVersion

    /// Stable identifier.  Used to key the on-disk JSON and icon files.
    let id: UUID

    /// Feed display title (also becomes the `Feed.title`).
    var name: String

    /// Source page URL the recipe runs against on every refresh.
    var siteURL: String

    /// How to fetch the page before running selectors.
    ///
    /// - `.staticHTML`: plain `URLSession` GET. Fast, but can't see
    ///   content that's rendered by client-side JavaScript.
    /// - `.rendered`: loads the page in a `WKWebView` and waits for the
    ///   DOM to hydrate. Needed for React / Vue / Next-client-rendered
    ///   pages like the Claude Blog or most modern SPAs.
    var fetchMode: FetchMode = .staticHTML

    /// CSS selector matching each repeating article container on the
    /// page (e.g. `"article.post"`, `"li.entry"`, `"[data-testid=card]"`).
    /// All the other selectors are run *relative to* each match.
    var itemSelector: String

    /// Selector for the item's title.  If `nil`, the engine falls back
    /// to the item's own text content.
    var titleSelector: String?

    /// Selector for the link to the article.  If `nil`, the engine
    /// looks for a descendant `<a href>` inside the item.
    var linkSelector: String?

    /// Attribute the link URL lives on (defaults to `href`).
    var linkAttribute: String = "href"

    /// Selector for a short summary.  Optional.
    var summarySelector: String?

    /// Selector for the item's hero image.  Optional.
    var imageSelector: String?

    /// Attribute the image URL lives on (defaults to `src`).
    /// Some lazy-loaded galleries use `data-src`, `data-lazy-src`, etc.
    var imageAttribute: String = "src"

    /// Selector for the published date.  Optional.
    var dateSelector: String?

    /// Attribute the date lives on (e.g. `datetime`).  `nil` means
    /// use the element's text content.
    var dateAttribute: String?

    /// Selector for the author.  Optional.
    var authorSelector: String?

    /// Optional URL used to resolve *relative* hrefs/srcs when they
    /// can't be resolved against `siteURL` directly (rare - only set
    /// this if the feed items live under a different base path).
    var baseURL: String?

    /// Maximum items to ingest per refresh. Guards against runaway
    /// recipes that match hundreds of unrelated elements.
    var maxItems: Int = 50

    /// ISO-8601 timestamp of last edit.  Shown in the management UI.
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
        /// Fetch the raw HTML with `URLSession`.
        case staticHTML
        /// Load the page in a WKWebView and wait for JS hydration.
        case rendered
    }

    /// URL scheme used in the feeds table (`petal://<siteURL>`).
    var feedURL: String { "petal://\(siteURL)" }

    /// `true` when the given `Feed.url` string points at a Petal recipe.
    static func isPetalFeedURL(_ url: String) -> Bool {
        url.hasPrefix("petal://")
    }

    /// Extracts the site URL from a `petal://<siteURL>` feed URL.
    static func siteURL(from feedURL: String) -> String? {
        guard feedURL.hasPrefix("petal://") else { return nil }
        return String(feedURL.dropFirst("petal://".count))
    }
}
