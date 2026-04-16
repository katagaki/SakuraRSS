import SwiftUI

/// Self-contained button that presents the Petal builder in a sheet.
/// Owns its own presentation state so the parent Form is not invalidated
/// when the sheet opens or closes.
struct PetalGenerateButton: View {

    let seedURL: String

    @Environment(FeedManager.self) var feedManager
    @State private var showPetalBuilder = false

    var body: some View {
        Button {
            showPetalBuilder = true
        } label: {
            Label(String(localized: "AddFeed.Generate", table: "Petal"),
                  systemImage: "leaf.fill")
        }
        .sheet(isPresented: $showPetalBuilder) {
            PetalBuilderView(mode: .create(initialURL: seedURL))
                .environment(feedManager)
        }
    }
}
