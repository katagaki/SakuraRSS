import SwiftUI

/// EnhancedNavigation's adaptive shell everywhere it runs; visionOS keeps the
/// app's own tab strip.
enum BrowserLayout {
    case adaptive
    case regular

    static var current: BrowserLayout {
        #if os(visionOS)
        return .regular
        #else
        return .adaptive
        #endif
    }

    /// Mirrors when `AdaptiveTabContainer` swaps the bottom bar for its top bar.
    static var usesWideTabs: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
}

private struct BrowserLayoutKey: EnvironmentKey {
    static let defaultValue: BrowserLayout = .adaptive
}

extension EnvironmentValues {
    var browserLayout: BrowserLayout {
        get { self[BrowserLayoutKey.self] }
        set { self[BrowserLayoutKey.self] = newValue }
    }
}
