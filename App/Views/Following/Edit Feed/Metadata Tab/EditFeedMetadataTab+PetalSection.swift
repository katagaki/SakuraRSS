import SwiftUI

extension EditFeedMetadataTab {

    @ViewBuilder
    func petalSection(for feed: Feed) -> some View {
        if PetalRecipe.isPetalFeedURL(feed.url) {
            Section {
                if let recipe = PetalStore.shared.recipe(forFeedURL: feed.url) {
                    HStack {
                        Text(String(localized: "FeedEdit.SourceURL", table: "Petal"))
                        Spacer()
                        Text(recipe.siteURL)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Button {
                    showPetalBuilder = true
                } label: {
                    Label(String(localized: "FeedEdit.EditRecipe", table: "Petal"),
                          systemImage: "wand.and.stars")
                }
            } header: {
                Text(String(localized: "FeedEdit.Header", table: "Petal"))
            }
        }
    }
}
