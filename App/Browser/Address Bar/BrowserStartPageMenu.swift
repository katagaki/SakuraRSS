import SwiftUI

struct BrowserStartPageMenu: View {

    let actions: BrowserStartPageActions

    var body: some View {
        Menu {
            Button(action: actions.newList) {
                Label(String(localized: "Section.Lists.NewList", table: "Settings"),
                      systemImage: "text.badge.plus")
            }
            Button(action: actions.editQuickAccess) {
                Label(String(localized: "Today.QuickAccess.Edit", table: "Home"),
                      systemImage: "square.grid.2x2")
            }
            Button(action: actions.showWeatherSettings) {
                Label(String(localized: "TodayWeather.Settings.Title", table: "Home"),
                      systemImage: "cloud.sun")
            }
        } label: {
            Label(String(localized: "Tabs.More"), systemImage: "ellipsis")
        }
    }
}
