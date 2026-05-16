#if targetEnvironment(macCatalyst)
import SwiftUI
import Hanami

struct OpenProfileSettingsButton: View {

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(String(localized: "Menu.Settings", table: "Settings")) {
            openWindow(id: "ProfileWindow", value: "settings")
        }
        .keyboardShortcut(",", modifiers: .command)
    }
}
#endif
