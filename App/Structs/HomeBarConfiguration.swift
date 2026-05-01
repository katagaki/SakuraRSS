import Foundation

extension Notification.Name {
    static let homeBarConfigurationDidChange = Notification.Name("HomeBarConfigurationDidChange")
}

/// User-configurable layout of the home section selection bar. The Following
/// tab is always emitted as the first item by `TodayTabItem.items`, so it does
/// not appear in `orderedItems` or `enabledItems`.
struct HomeBarConfiguration: Equatable, Hashable, Sendable {

    static let storageKey = "Home.BarConfiguration"

    var orderedItems: [HomeBarItemKind]
    var enabledItems: Set<HomeBarItemKind>
    var topicCount: HomeBarTopicCount

    static let defaultOrderedItems: [HomeBarItemKind] = [
        .feeds, .podcasts, .bluesky, .instagram, .mastodon, .note,
        .pixelfed, .reddit, .substack, .vimeo, .x, .youtube, .niconico, .lists, .topics
    ]

    static let `default` = HomeBarConfiguration(
        orderedItems: defaultOrderedItems,
        enabledItems: Set(defaultOrderedItems.filter { $0 != .topics }),
        topicCount: .top3
    )

    static func load() -> HomeBarConfiguration {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(HomeBarConfiguration.self, from: data) else {
            return .default
        }
        return decoded.normalized()
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    /// Ensures every kind appears exactly once in the ordered list, appending
    /// any missing kinds at the end so newer item types remain reachable.
    func normalized() -> HomeBarConfiguration {
        var seen = Set<HomeBarItemKind>()
        var ordered: [HomeBarItemKind] = []
        for kind in orderedItems where !seen.contains(kind) {
            ordered.append(kind)
            seen.insert(kind)
        }
        for kind in HomeBarItemKind.allCases where !seen.contains(kind) {
            ordered.append(kind)
        }
        return HomeBarConfiguration(
            orderedItems: ordered,
            enabledItems: enabledItems.intersection(HomeBarItemKind.allCases),
            topicCount: topicCount
        )
    }
}

extension HomeBarConfiguration: Codable {

    private enum CodingKeys: String, CodingKey {
        case orderedItems, enabledItems, topicCount
    }

    /// Pre-existing rawValue for the legacy aggregate "feed sections" item.
    private static let legacyFeedSectionsRaw = "feedSections"
    /// Pre-existing rawValue for the legacy "following" item, now implicit.
    private static let legacyFollowingRaw = "following"
    /// Order to insert per-section items when migrating a legacy
    /// `feedSections` placeholder.
    private static let legacyFeedSectionExpansion: [HomeBarItemKind] = [
        .feeds, .podcasts, .bluesky, .instagram, .mastodon, .note,
        .pixelfed, .reddit, .substack, .vimeo, .x, .youtube, .niconico
    ]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawOrdered = (try? container.decode([String].self, forKey: .orderedItems)) ?? []
        let rawEnabled = (try? container.decode([String].self, forKey: .enabledItems)) ?? []
        let topicCount = (try? container.decode(HomeBarTopicCount.self, forKey: .topicCount)) ?? .top3

        var ordered: [HomeBarItemKind] = []
        var seenOrdered = Set<HomeBarItemKind>()
        for raw in rawOrdered {
            switch raw {
            case Self.legacyFollowingRaw:
                continue
            case Self.legacyFeedSectionsRaw:
                for kind in Self.legacyFeedSectionExpansion where !seenOrdered.contains(kind) {
                    ordered.append(kind)
                    seenOrdered.insert(kind)
                }
            default:
                if let kind = HomeBarItemKind(rawValue: raw), !seenOrdered.contains(kind) {
                    ordered.append(kind)
                    seenOrdered.insert(kind)
                }
            }
        }

        var enabled = Set<HomeBarItemKind>()
        for raw in rawEnabled {
            switch raw {
            case Self.legacyFollowingRaw:
                continue
            case Self.legacyFeedSectionsRaw:
                Self.legacyFeedSectionExpansion.forEach { enabled.insert($0) }
            default:
                if let kind = HomeBarItemKind(rawValue: raw) {
                    enabled.insert(kind)
                }
            }
        }

        self.orderedItems = ordered
        self.enabledItems = enabled
        self.topicCount = topicCount
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(orderedItems.map(\.rawValue), forKey: .orderedItems)
        try container.encode(enabledItems.map(\.rawValue), forKey: .enabledItems)
        try container.encode(topicCount, forKey: .topicCount)
    }
}
