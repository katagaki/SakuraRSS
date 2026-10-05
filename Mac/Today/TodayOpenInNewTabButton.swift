import SwiftUI

struct TodayOpenInNewTabButton: View {

    let location: BrowserLocation
    let actions: TodayActions

    var body: some View {
        Button(String(localized: "Menu.OpenInNewTab", table: "Browser"), systemImage: "plus.square.on.square") {
            actions.openInNewTab(location)
        }
    }
}
