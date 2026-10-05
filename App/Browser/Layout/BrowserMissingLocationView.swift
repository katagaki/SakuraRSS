import SwiftUI

struct BrowserMissingLocationView: View {

    enum Reason {
        case feed
        case list
    }

    let reason: Reason

    private var title: String {
        switch reason {
        case .feed: String(localized: "Location.MissingFeed", table: "Browser")
        case .list: String(localized: "Location.MissingList", table: "Browser")
        }
    }

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "questionmark.circle")
        } description: {
            Text(String(localized: "Location.MissingDescription", table: "Browser"))
        }
    }
}
