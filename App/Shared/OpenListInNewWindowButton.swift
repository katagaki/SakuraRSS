#if targetEnvironment(macCatalyst)
import SwiftUI
import Hanami

struct OpenListInNewWindowButton: View {

    @Environment(\.openWindow) private var openWindow
    let list: FeedList

    var body: some View {
        Button {
            openWindow(id: "ListWindow", value: list.id)
        } label: {
            Label(
                String(localized: "ListMenu.OpenInNewWindow", table: "Lists"),
                systemImage: "macwindow.badge.plus"
            )
        }
    }
}
#endif
