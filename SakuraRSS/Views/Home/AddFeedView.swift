import SwiftUI

struct AddFeedView: View {

    @Environment(FeedManager.self) var feedManager

    var initialURL: String = ""

    @State private var showXLogin = false
    @State private var showInstagramLogin = false
    @State private var showPetalBuilder = false
    @State private var petalSeedURL = ""

    var body: some View {
        AddFeedForm(
            initialURL: initialURL,
            showXLogin: $showXLogin,
            showInstagramLogin: $showInstagramLogin,
            showPetalBuilder: $showPetalBuilder,
            petalSeedURL: $petalSeedURL
        )
        .interactiveDismissDisabled()
        .sheet(isPresented: $showXLogin) {
            XLoginView()
        }
        .sheet(isPresented: $showInstagramLogin) {
            InstagramLoginView()
        }
        .sheet(isPresented: $showPetalBuilder) {
            PetalBuilderView(mode: .create(initialURL: petalSeedURL))
                .environment(feedManager)
        }
    }
}
