import SwiftUI

/// Self-contained button that presents the Petal recipe editor in a sheet.
/// Owns its own presentation state so the parent Form is not invalidated
/// when the sheet opens or closes.
struct PetalEditButton: View {

    let feed: Feed

    @Environment(FeedManager.self) var feedManager
    @State private var showPetalBuilder = false

    var body: some View {
        Button {
            showPetalBuilder = true
        } label: {
            Label(String(localized: "FeedEdit.EditRecipe", table: "Petal"),
                  systemImage: "wand.and.stars")
        }
        .sheet(isPresented: $showPetalBuilder) {
            if let recipe = PetalStore.shared.recipe(forFeedURL: feed.url) {
                PetalBuilderView(mode: .edit(feed: feed, recipe: recipe))
                    .environment(feedManager)
            }
        }
    }
}
