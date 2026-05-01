import Foundation

extension Notification.Name {
    static let homeBarConfigurationDidChange = Notification.Name("HomeBarConfigurationDidChange")
}

/// User-configurable layout of the home section selection bar.
struct HomeBarConfiguration: Codable, Equatable, Hashable, Sendable {

    static let storageKey = "Home.BarConfiguration"

    var orderedItems: [HomeBarItemKind]
    var enabledItems: Set<HomeBarItemKind>
    var topicCount: HomeBarTopicCount

    static let `default` = HomeBarConfiguration(
        orderedItems: [.following, .feedSections, .lists],
        enabledItems: [.following, .feedSections, .lists],
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
        UserDefaults.standard.set(data, forKey: storageKey)
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
            enabledItems: enabledItems,
            topicCount: topicCount
        )
    }
}
