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
            Image(systemName: "ellipsis")
                .font(.system(size: 17))
                .padding(.vertical, 8)
                .contentShape(.rect)
        }
    }
}
