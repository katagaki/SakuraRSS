import Foundation
import Hanami
import Observation

/// Finds the feeds behind an address and subscribes to them, the way iOS's
/// add feed screen does: the address as a feed first, then the page's links,
/// then the whole domain.
@Observable
final class FeedDiscoverySession {

    private(set) var urlString: String
    private(set) var hasSearched = false
    private(set) var discoveredFeeds: [DiscoveredFeed] = []
    private(set) var isSearching = false
    private(set) var errorMessage: String?
    private(set) var addingURLs: Set<String> = []
    private(set) var addedURLs: Set<String> = []

    init(urlString: String) {
        self.urlString = urlString
    }

    func search(_ input: String) async {
        guard let normalized = BrowserAddressInput.normalizedURLString(from: input) else {
            errorMessage = String(localized: "AddFeed.InvalidURL", table: "Feeds")
            discoveredFeeds = []
            hasSearched = true
            return
        }
        urlString = normalized
        hasSearched = true
        isSearching = true
        defer { isSearching = false }
        var results: [DiscoveredFeed] = []
        if let feed = await directFeed() {
            results.append(feed)
        }
        if let url = URL(string: urlString) {
            results += await FeedDiscovery.shared.discoverFeeds(fromPageURL: url)
            if results.isEmpty, let host = url.host() {
                results += await FeedDiscovery.shared.discoverFeeds(forDomain: host)
            }
        }
        var seenURLs = Set<String>()
        discoveredFeeds = results
            .filter { seenURLs.insert($0.url).inserted }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        errorMessage = discoveredFeeds.isEmpty ? String(localized: "AddFeed.NoFeedsFound", table: "Feeds") : nil
    }

    /// X and Instagram feeds need a signed-in session, which the Mac can't
    /// create yet.
    func canAdd(_ feed: DiscoveredFeed) -> Bool {
        if XProvider.isFeedURL(feed.url) {
            return UserDefaults.standard.bool(forKey: "Labs.XProfileFeeds") && XProvider.hasSession()
        }
        if InstagramProvider.isFeedURL(feed.url) {
            return UserDefaults.standard.bool(forKey: "Labs.InstagramProfileFeeds") && InstagramProvider.hasSession()
        }
        return true
    }

    func add(_ feed: DiscoveredFeed, to feedManager: FeedManager) async {
        guard canAdd(feed), !addingURLs.contains(feed.url), !addedURLs.contains(feed.url) else { return }
        addingURLs.insert(feed.url)
        defer { addingURLs.remove(feed.url) }
        do {
            _ = try await feedManager.addFeedFetchingMetadata(url: feed.url, title: feed.title, siteURL: feed.siteURL)
            addedURLs.insert(feed.url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func directFeed() async -> DiscoveredFeed? {
        guard let url = URL(string: urlString), RedditWebFeedURL(url: url) == nil else { return nil }
        let fetchURL = RedirectDomains.redirectedURL(url)
        guard let (data, response) = try? await URLSession.shared.data(for: .sakura(url: fetchURL)),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let parsed = RSSParser().parse(data: data) else { return nil }
        return DiscoveredFeed(
            title: parsed.title.isEmpty ? (url.host() ?? urlString) : parsed.title,
            url: urlString,
            siteURL: parsed.siteURL.isEmpty ? urlString : parsed.siteURL
        )
    }
}
