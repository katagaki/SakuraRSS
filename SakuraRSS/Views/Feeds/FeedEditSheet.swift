import SwiftUI

struct FeedEditSheet: View {

    @Environment(FeedManager.self) var feedManager

    let feed: Feed

    @State private var showPetalBuilder = false

    var body: some View {
        FeedEditForm(feed: feed, showPetalBuilder: $showPetalBuilder)
            .sheet(isPresented: $showPetalBuilder) {
                if let recipe = PetalStore.shared.recipe(forFeedURL: feed.url) {
                    PetalBuilderView(mode: .edit(feed: feed, recipe: recipe))
                        .environment(feedManager)
                }
            }
    }
}
