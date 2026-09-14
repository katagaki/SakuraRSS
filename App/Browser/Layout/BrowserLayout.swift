import SwiftUI

/// Safari uses two very different shells: a bottom address bar with a
/// full-screen tab switcher on iPhone, and a top tab strip on iPad and Mac.
enum BrowserLayout {
    case compact
    case regular

    static func resolve(horizontalSizeClass: UserInterfaceSizeClass?) -> BrowserLayout {
        #if os(visionOS) || targetEnvironment(macCatalyst)
        return .regular
        #else
        guard UIDevice.current.userInterfaceIdiom == .pad else { return .compact }
        return horizontalSizeClass == .regular ? .regular : .compact
        #endif
    }
}

private struct BrowserLayoutKey: EnvironmentKey {
    static let defaultValue: BrowserLayout = .compact
}

extension EnvironmentValues {
    var browserLayout: BrowserLayout {
        get { self[BrowserLayoutKey.self] }
        set { self[BrowserLayoutKey.self] = newValue }
    }
}
