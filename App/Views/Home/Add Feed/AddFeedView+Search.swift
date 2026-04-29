import SwiftUI

extension AddFeedView {

    func searchFeeds() {
        isSearching = true
        errorMessage = nil
        discoveredFeeds = []

        Task {
            var results: [DiscoveredFeed] = []

            if let feed = await tryDirectFeedURL(urlInput) {
                results.append(feed)
            }

            let normalizedURL = normalizeURL(urlInput)
            if let url = URL(string: normalizedURL) {
                let urlFeeds = await FeedDiscovery.shared.discoverFeeds(fromPageURL: url)
                results.append(contentsOf: urlFeeds)
            }

            if results.isEmpty {
                let domain = extractDomain(from: urlInput)
                let domainFeeds = await FeedDiscovery.shared.discoverFeeds(forDomain: domain)
                results.append(contentsOf: domainFeeds)
            }

            var seen = Set<String>()
            results = results.filter { seen.insert($0.url).inserted }

            results.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

            await MainActor.run {
                withAnimation(.smooth.speed(2.0)) {
                    isSearching = false
                    if results.isEmpty {
                        errorMessage = String(localized: "AddFeed.NoFeedsFound", table: "Feeds")
                    } else {
                        discoveredFeeds = results
                    }
                }
            }
        }
    }

    func tryDirectFeedURL(_ input: String) async -> DiscoveredFeed? {
        let urlString = normalizeURL(input)
        guard let url = URL(string: urlString) else { return nil }
        let fetchURL = RedirectDomains.redirectedURL(url)

        do {
            let (data, response) = try await URLSession.shared.data(for: .sakura(url: fetchURL))
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }

            let parser = RSSParser()
            guard let parsed = parser.parse(data: data) else { return nil }

            let siteURL = parsed.siteURL.isEmpty ? urlString : parsed.siteURL
            let title = parsed.title.isEmpty ? (url.host ?? urlString) : parsed.title
            return DiscoveredFeed(title: title, url: urlString, siteURL: siteURL)
        } catch {
            return nil
        }
    }
}
