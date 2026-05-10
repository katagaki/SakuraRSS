import Foundation
import Hanami

extension Notification.Name {
    static let homeBarConfigurationDidChange = Notification.Name("HomeBarConfigurationDidChange")
}

struct HomeBarConfiguration: Equatable, Hashable, Sendable {

    static let storageKey = "Home.BarConfiguration"

    var orderedItems: [HomeBarItemKind]
    var enabledItems: Set<HomeBarItemKind>
    var topicCount: HomeBarTopicCount

    static let defaultOrderedItems: [HomeBarItemKind] = [
        .today, .following, .feeds, .podcasts, .bluesky, .fediverse, .instagram, .note,
        .reddit, .substack, .vimeo, .x, .youtube, .niconico, .lists, .topics
    ]

    static let `default` = HomeBarConfiguration(
        orderedItems: defaultOrderedItems,
        enabledItems: Set(defaultOrderedItems),
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
    /// Pre-existing rawValues for the legacy `mastodon` and `pixelfed` items,
    /// now folded into the unified Fediverse section.
    private static let legacyMastodonRaw = "mastodon"
    private static let legacyPixelfedRaw = "pixelfed"
    /// Order to insert per-section items when migrating a legacy
    /// `feedSections` placeholder.
    private static let legacyFeedSectionExpansion: [HomeBarItemKind] = [
        .feeds, .podcasts, .bluesky, .fediverse, .instagram, .note,
        .reddit, .substack, .vimeo, .x, .youtube, .niconico
    ]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawOrdered = (try? container.decode([String].self, forKey: .orderedItems)) ?? []
        let rawEnabled = (try? container.decode([String].self, forKey: .enabledItems)) ?? []
        let topicCount = (try? container.decode(HomeBarTopicCount.self, forKey: .topicCount)) ?? .top3

        var (ordered, seenOrdered) = Self.decodeOrderedItems(rawOrdered: rawOrdered)
        var enabled = Self.decodeEnabledItems(rawEnabled: rawEnabled)

        // Today was introduced after the bar config shipped. Existing users get
        // it inserted at the front of their order and enabled by default so the
        // tab is discoverable without resetting customization.
        let hasTodayInRawOrder = rawOrdered.contains(HomeBarItemKind.today.rawValue)
        if !seenOrdered.contains(.today) {
            ordered.insert(.today, at: 0)
            seenOrdered.insert(.today)
        }
        if !hasTodayInRawOrder {
            enabled.insert(.today)
        }

        let hasFollowingInRawOrder = rawOrdered.contains(HomeBarItemKind.following.rawValue)
        if !seenOrdered.contains(.following) {
            let insertIndex = ordered.firstIndex(of: .today).map { $0 + 1 } ?? 0
            ordered.insert(.following, at: insertIndex)
        }
        if !hasFollowingInRawOrder {
            enabled.insert(.following)
        }

        self.orderedItems = ordered
        self.enabledItems = enabled
        self.topicCount = topicCount
    }

    private static func decodeOrderedItems(
        rawOrdered: [String]
    ) -> (ordered: [HomeBarItemKind], seen: Set<HomeBarItemKind>) {
        var ordered: [HomeBarItemKind] = []
        var seen = Set<HomeBarItemKind>()
        for raw in rawOrdered {
            switch raw {
            case Self.legacyFeedSectionsRaw:
                for kind in Self.legacyFeedSectionExpansion where !seen.contains(kind) {
                    ordered.append(kind)
                    seen.insert(kind)
                }
            case Self.legacyMastodonRaw, Self.legacyPixelfedRaw:
                if !seen.contains(.fediverse) {
                    ordered.append(.fediverse)
                    seen.insert(.fediverse)
                }
            default:
                if let kind = HomeBarItemKind(rawValue: raw), !seen.contains(kind) {
                    ordered.append(kind)
                    seen.insert(kind)
                }
            }
        }
        return (ordered, seen)
    }

    private static func decodeEnabledItems(rawEnabled: [String]) -> Set<HomeBarItemKind> {
        var enabled = Set<HomeBarItemKind>()
        for raw in rawEnabled {
            switch raw {
            case Self.legacyFeedSectionsRaw:
                Self.legacyFeedSectionExpansion.forEach { enabled.insert($0) }
            case Self.legacyMastodonRaw, Self.legacyPixelfedRaw:
                enabled.insert(.fediverse)
            default:
                if let kind = HomeBarItemKind(rawValue: raw) {
                    enabled.insert(kind)
                }
            }
        }
        return enabled
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(orderedItems.map(\.rawValue), forKey: .orderedItems)
        try container.encode(enabledItems.map(\.rawValue), forKey: .enabledItems)
        try container.encode(topicCount, forKey: .topicCount)
    }
}
