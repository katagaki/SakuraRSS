#if targetEnvironment(macCatalyst)
import SwiftUI

struct OpenProfileSettingsButton: View {

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(String(localized: "Menu.Settings", table: "Settings")) {
            openWindow(id: "ProfileWindow")
        }
        .keyboardShortcut(",", modifiers: .command)
    }
}
#endif
