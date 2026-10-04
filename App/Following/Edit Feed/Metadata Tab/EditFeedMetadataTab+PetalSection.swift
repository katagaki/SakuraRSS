import SwiftUI
import Hanami

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
                // The recipe builder hasn't been brought to the Mac yet.
                #if !os(macOS)
                Button {
                    selectedPetalRecipe = PetalStore.shared.recipe(forFeedURL: feed.url)
                        ?? PetalRecipe.recoveryRecipe(name: feed.title, feedURL: feed.url)
                } label: {
                    Label(String(localized: "FeedEdit.EditRecipe", table: "Petal"),
                          systemImage: "wand.and.stars")
                }
                #endif
            } header: {
                Text(String(localized: "FeedEdit.Header", table: "Petal"))
            }
        }
    }
}
