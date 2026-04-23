import Foundation

// MARK: - JSON Models

nonisolated struct SuggestedFeedsData: Codable, Sendable {
    let feeds: [SuggestedRegion]
}

nonisolated struct SuggestedRegion: Codable, Sendable {
    let countryCode: String
    let region: String
    let topics: [SuggestedTopic]
}

nonisolated struct SuggestedTopic: Codable, Sendable {
    let title: String
    let sites: [SuggestedSite]
}

nonisolated struct SuggestedSite: Codable, Sendable {
    let title: String
    let feedUrl: String
}

// MARK: - Loader

enum SuggestedFeedsLoader {
    static func load() -> SuggestedFeedsData? {
        guard let url = Bundle.main.url(forResource: "Feeds", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(SuggestedFeedsData.self, from: data)
    }

    /// Returns merged topics for universal and current-region feeds, with sites sorted.
    static func topicsForCurrentRegion() -> [SuggestedTopic] {
        guard let feedsData = load() else { return [] }

        let currentCountryCode = Locale.current.region?.identifier ?? ""

        let universalRegion = feedsData.feeds.first { $0.countryCode == "universal" }
        let localRegion = feedsData.feeds.first { $0.countryCode == currentCountryCode }

        var topicMap: [String: [SuggestedSite]] = [:]
        var topicOrder: [String] = []

        if let universal = universalRegion {
            for topic in universal.topics {
                topicMap[topic.title] = topic.sites
                topicOrder.append(topic.title)
            }
        }

        if let local = localRegion {
            for topic in local.topics {
                if var existing = topicMap[topic.title] {
                    existing.append(contentsOf: topic.sites)
                    topicMap[topic.title] = existing
                } else {
                    topicMap[topic.title] = topic.sites
                    topicOrder.append(topic.title)
                }
            }
        }

        return topicOrder.compactMap { title in
            guard let sites = topicMap[title] else { return nil }
            let sorted = sites.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            return SuggestedTopic(title: title, sites: sorted)
        }
    }
}
