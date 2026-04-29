import Foundation

/// Loads noise-stripping rules used by `ArticleExtractor` from bundled JSON resources.
enum NoiseData {

    static let selectors: [String] = loadGroupedList(
        resource: "NoiseSelectors",
        key: \GroupedSelectors.groups,
        valueKey: \SelectorGroup.selectors
    )

    static let classPatterns: [String] = loadGroupedList(
        resource: "NoiseClassPatterns",
        key: \GroupedPatterns.groups,
        valueKey: \PatternGroup.patterns
    )

    static let unsafeInsideArticle: Set<String> = Set(
        loadFlatList(resource: "UnsafeInsideArticle")
    )

    static let advertisementTextPatterns: Set<String> = Set(
        loadFlatList(resource: "AdvertisementTextPatterns")
    )

    // MARK: - Models

    private struct GroupedSelectors: Decodable {
        let groups: [SelectorGroup]
    }

    private struct SelectorGroup: Decodable {
        let selectors: [String]
    }

    private struct GroupedPatterns: Decodable {
        let groups: [PatternGroup]
    }

    private struct PatternGroup: Decodable {
        let patterns: [String]
    }

    private struct FlatList: Decodable {
        let patterns: [String]
    }

    // MARK: - Loading helpers

    private static func loadGroupedList<Container: Decodable, Group>(
        resource: String,
        key: KeyPath<Container, [Group]>,
        valueKey: KeyPath<Group, [String]>
    ) -> [String] {
        guard let container: Container = decodeResource(resource) else { return [] }
        return container[keyPath: key].flatMap { $0[keyPath: valueKey] }
    }

    private static func loadFlatList(resource: String) -> [String] {
        guard let container: FlatList = decodeResource(resource) else { return [] }
        return container.patterns
    }

    private static func decodeResource<T: Decodable>(_ name: String) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data)
    }

}
