import SwiftUI

struct BrowserStartPageMenu: View {

    let actions: BrowserStartPageActions

    var body: some View {
        Menu {
            Button(action: actions.newList) {
                Label(String(localized: "Section.Lists.NewList", table: "Settings"),
                      systemImage: "text.badge.plus")
            }
        } label: {
            Label(String(localized: "Tabs.More"), systemImage: "ellipsis")
        }
    }
}
