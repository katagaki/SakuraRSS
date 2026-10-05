import Foundation

/// Produces the handful of tags Sakura applies without being asked, so a
/// bookmark collection stays browsable before the user has organized anything.
public nonisolated enum BookmarkAutoTagger {

    private static let topicKeywords: [String: [String]] = [
        "Swift": ["swift", "swiftui", "xcode", "concurrency"],
        "Apple": ["apple", "ios", "macos", "visionos", "iphone", "ipad"],
        "Design": ["design", "typography", "interface", "ux"],
        "AI": ["llm", "machine learning", "inference", "neural"],
        "Recipes": ["recipe", "ramen", "bake", "kitchen", "cook"],
        "Travel": ["travel", "itinerary", "flight", "hotel"],
        "Business": ["startup", "funding", "revenue", "pricing"],
        "Photography": ["camera", "lens", "photo"]
    ]

    public static func suggestedTags(title: String, url: String, limit: Int = 3) -> [String] {
        var suggestions: [String] = []
        if let siteTag = siteTag(for: url) {
            suggestions.append(siteTag)
        }
        let haystack = "\(title) \(url)".lowercased()
        for (tag, keywords) in topicKeywords.sorted(by: { $0.key < $1.key })
        where keywords.contains(where: haystack.contains) {
            suggestions.append(tag)
        }
        return Array(suggestions.prefix(limit))
    }

    /// The site's own name, when the host gives one worth showing.
    public static func siteTag(for url: String) -> String? {
        guard let host = URL(string: url)?.host()?.lowercased() else { return nil }
        let stripped = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        if let known = knownSiteNames[stripped] { return known }
        guard let firstComponent = stripped.split(separator: ".").first else { return nil }
        let name = String(firstComponent)
        guard name.count > 2 else { return nil }
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    /// Hosts whose name can't be recovered by capitalizing the first label.
    private static let knownSiteNames: [String: String] = [
        "news.ycombinator.com": "Hacker News",
        "seriouseats.com": "Serious Eats",
        "theverge.com": "The Verge",
        "arstechnica.com": "Ars Technica",
        "nytimes.com": "NYT",
        "bbc.co.uk": "BBC",
        "bbc.com": "BBC",
        "developer.apple.com": "Apple",
        "9to5mac.com": "9to5Mac",
        "macrumors.com": "MacRumors",
        "youtube.com": "YouTube",
        "youtu.be": "YouTube",
        "github.com": "GitHub",
        "stackoverflow.com": "Stack Overflow",
        "reddit.com": "Reddit",
        "x.com": "X"
    ]
}
