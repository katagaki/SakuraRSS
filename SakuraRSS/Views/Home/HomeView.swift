import SwiftUI

struct HomeView: View {

    @Environment(FeedManager.self) var feedManager
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            AllArticlesView()
                .navigationDestination(for: Feed.self) { feed in
                    FeedArticlesView(feed: feed)
                }
        }
    }
}
