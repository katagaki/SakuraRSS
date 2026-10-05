import SwiftUI

extension View {

    /// Inset grouped on iOS; macOS has no such list style, so its settings
    /// panes use the inset one.
    func settingsListStyle() -> some View {
        #if os(macOS)
        listStyle(.inset)
        #else
        listStyle(.insetGrouped)
        #endif
    }
}
