import SwiftUI

enum BrowserLayout {
    /// Mirrors when `AdaptiveTabContainer` swaps the bottom bar for its top bar.
    static var usesWideTabs: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
}
