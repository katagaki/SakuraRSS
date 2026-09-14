import SwiftUI

struct BrowserStartPageEmptyState: View {

    var body: some View {
        ContentUnavailableView {
            Label(String(localized: "StartPage.NoFeeds.Title", table: "Browser"),
                  systemImage: "dot.radiowaves.up.forward")
        } description: {
            Text(String(localized: "StartPage.NoFeeds.Description", table: "Browser"))
        }
    }
}
