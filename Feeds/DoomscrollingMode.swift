import Foundation

/// Bypass values used while Doomscrolling Mode is active. The user's stored
/// settings are preserved; only the effective values returned here change.
enum DoomscrollingMode {

    static let storageKey = "Articles.DoomscrollingMode"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: storageKey)
    }

    static func effectiveHideViewedContent(_ stored: Bool) -> Bool {
        isEnabled ? false : stored
    }

    static func effectiveBatchingMode(_ stored: BatchingMode) -> BatchingMode {
        isEnabled ? .items25 : stored
    }

    static func effectiveScrollMarkAsRead(_ stored: Bool) -> Bool {
        isEnabled ? false : stored
    }
}
