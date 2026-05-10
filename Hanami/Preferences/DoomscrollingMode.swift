import Foundation

/// Bypass values used while Doomscrolling Mode is active. The user's stored
/// settings are preserved; only the effective values returned here change.
public nonisolated enum DoomscrollingMode {

    public static let storageKey = "Articles.DoomscrollingMode"

    public static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: storageKey)
    }

    public static func effectiveHideViewedContent(_ stored: Bool) -> Bool {
        isEnabled ? false : stored
    }

    public static func effectiveBatchingMode(_ stored: BatchingMode) -> BatchingMode {
        isEnabled ? .items25 : stored
    }

    public static func effectiveScrollMarkAsRead(_ stored: Bool) -> Bool {
        isEnabled ? false : stored
    }
}
