import SwiftUI

@MainActor
@Observable
final class FeatureFlagStore {

    static let shared = FeatureFlagStore()

    private static let enableCommandPrefix = "/enable-feature:"
    private static let disableCommandPrefix = "/disable-feature:"

    private(set) var enabledFlags: Set<FeatureFlag>

    private init() {
        var flags: Set<FeatureFlag> = []
        for flag in FeatureFlag.allCases {
            _ = flag.buildTimeKey
            if UserDefaults.standard.bool(forKey: Self.defaultsKey(for: flag)) {
                flags.insert(flag)
            }
        }
        self.enabledFlags = flags
    }

    func isEnabled(_ flag: FeatureFlag) -> Bool {
        enabledFlags.contains(flag)
    }

    @discardableResult
    func handle(searchInput: String) -> Bool {
        let trimmed = searchInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if let key = parseKey(from: trimmed, prefix: Self.enableCommandPrefix),
           let flag = FeatureFlag.flag(forBuildTimeKey: key) {
            enable(flag)
            return true
        }
        if let key = parseKey(from: trimmed, prefix: Self.disableCommandPrefix),
           let flag = FeatureFlag.flag(forBuildTimeKey: key) {
            disable(flag)
            return true
        }
        return false
    }

    private func enable(_ flag: FeatureFlag) {
        guard !enabledFlags.contains(flag) else { return }
        enabledFlags.insert(flag)
        UserDefaults.standard.set(true, forKey: Self.defaultsKey(for: flag))
    }

    private func disable(_ flag: FeatureFlag) {
        guard enabledFlags.contains(flag) else { return }
        enabledFlags.remove(flag)
        UserDefaults.standard.set(false, forKey: Self.defaultsKey(for: flag))
    }

    private static func defaultsKey(for flag: FeatureFlag) -> String {
        "FeatureFlag.\(flag.rawValue).Enabled"
    }

    private func parseKey(from input: String, prefix: String) -> String? {
        guard input.hasPrefix(prefix) else { return nil }
        let key = String(input.dropFirst(prefix.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return key.isEmpty ? nil : key
    }
}
