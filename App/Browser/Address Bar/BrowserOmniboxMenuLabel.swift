import EnhancedNavigation
import SwiftUI

extension EnvironmentValues {
    /// Set by the compact address capsule, so the menu's tap target runs out
    /// to the capsule's end rather than stopping at the glyph.
    @Entry var browserOmniboxMenuInsets: EdgeInsets?
}

/// A frame or content shape added outside a `Menu` doesn't widen what it
/// responds to, so the omnibox menus size their tap target in the label.
struct BrowserOmniboxMenuLabel: View {

    @Environment(\.browserOmniboxMenuInsets) private var insets
    let title: String
    let systemImage: String

    var body: some View {
        if let insets {
            Label(title, systemImage: systemImage)
                .padding(insets)
                .frame(minHeight: TabBottomBarMetrics.itemHeight)
                .contentShape(.rect)
        } else {
            Label(title, systemImage: systemImage)
                .frame(minWidth: 40, minHeight: 40)
                .contentShape(.rect)
        }
    }
}
