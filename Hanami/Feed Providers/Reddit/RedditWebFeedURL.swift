import Foundation

public nonisolated struct RedditWebFeedURL: Sendable {
    public let subreddit: String
    public let sort: String
    public let timeRange: String?
    public let pageURL: URL

    public init?(url: URL) {
        guard RedditProvider.matchesHost(url.host) else { return nil }
        let segments = url.pathComponents.filter { $0 != "/" }
        guard segments.count >= 2,
              segments[0].lowercased() == "r" else { return nil }

        let rawSubreddit = segments[1]
        let subreddit = rawSubreddit.lowercased().hasSuffix(".rss")
            ? String(rawSubreddit.dropLast(4)) : rawSubreddit
        let allowedName = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        guard !subreddit.isEmpty,
              subreddit.unicodeScalars.allSatisfy({ allowedName.contains($0) }) else { return nil }

        let remainder = Array(segments.dropFirst(2))
        let rawSort = remainder.first ?? "hot"
        let normalizedSort = rawSort.lowercased() == ".rss" ? "hot" : rawSort.lowercased().hasSuffix(".rss")
            ? String(rawSort.dropLast(4)).lowercased() : rawSort.lowercased()
        let sort = normalizedSort
        let allowedSorts: Set<String> = ["hot", "new", "top", "rising", "controversial"]
        guard allowedSorts.contains(sort),
              remainder.count <= 2,
              remainder.count < 2 || remainder[1].lowercased() == ".rss" else { return nil }

        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let requestedRange = queryItems.first { $0.name.lowercased() == "t" }?.value?.lowercased()
        let allowedRanges: Set<String> = ["hour", "day", "week", "month", "year", "all"]
        let timeRange = (sort == "top" || sort == "controversial") && requestedRange.map(allowedRanges.contains) == true
            ? requestedRange : nil

        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.reddit.com"
        components.path = "/r/\(subreddit)/\(sort)/"
        if let timeRange {
            components.queryItems = [URLQueryItem(name: "t", value: timeRange)]
        }
        guard let pageURL = components.url else { return nil }
        self.subreddit = subreddit
        self.sort = sort
        self.timeRange = timeRange
        self.pageURL = pageURL
    }
}
