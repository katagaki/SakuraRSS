import SwiftUI

struct ContentEmptyStateView: View {

    var body: some View {
        ContentUnavailableView(
            String(localized: "Empty.Title", table: "Articles"),
            systemImage: "tray"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
