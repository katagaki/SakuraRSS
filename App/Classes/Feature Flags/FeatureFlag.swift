import Foundation

enum FeatureFlag: String, CaseIterable, Sendable {
    case nextgenYouTubePlayer

    private var plistKey: String {
        switch self {
        case .nextgenYouTubePlayer:
            return "NEXTGEN_YOUTUBE_PLAYER"
        }
    }

    var buildTimeKey: String? {
        #if DEBUG
        return Self.debugKeys[self]
        #else
        guard let value = Self.featureKeys[plistKey], !value.isEmpty else {
            return nil
        }
        return value
        #endif
    }

    static func flag(forBuildTimeKey key: String) -> FeatureFlag? {
        guard !key.isEmpty else { return nil }
        return allCases.first { $0.buildTimeKey == key }
    }

    private static let featureKeys: [String: String] = loadFeatureKeys()

    private static func loadFeatureKeys() -> [String: String] {
        guard
            let url = Bundle.main.url(forResource: "FeatureKeys", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
            let dict = plist as? [String: String]
        else {
            return [:]
        }
        return dict
    }

    #if DEBUG
    private static let debugKeys: [FeatureFlag: String] = {
        let keys = Dictionary(
            uniqueKeysWithValues: allCases.map { ($0, randomDebugKey()) }
        )
        let listing = allCases
            .map { "  \($0.rawValue) = \(keys[$0] ?? "?")" }
            .joined(separator: "\n")
        log("FeatureFlag", "Debug keys for this launch:\n\(listing)")
        return keys
    }()

    private static func randomDebugKey() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12).lowercased()
    }
    #endif
}
