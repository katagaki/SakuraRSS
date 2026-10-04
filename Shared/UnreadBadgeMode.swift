import Foundation
import Hanami

nonisolated enum UnreadBadgeMode: String, CaseIterable, Sendable {
    case homeScreenOnly
    case none

    static let storageKey = "Display.UnreadBadgeMode"

    static func migrateRemovedHomeTabModes(defaults: UserDefaults) {
        switch defaults.string(forKey: storageKey) {
        case "homeScreenAndHomeTab":
            defaults.set(UnreadBadgeMode.homeScreenOnly.rawValue, forKey: storageKey)
        case "homeTabOnly":
            defaults.set(UnreadBadgeMode.none.rawValue, forKey: storageKey)
        default:
            break
        }
    }
}
