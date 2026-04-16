import SwiftUI

enum AddFeedSheetDestination: Identifiable, Equatable {
    case xLogin
    case instagramLogin
    case petalBuilder(seedURL: String)

    var id: String {
        switch self {
        case .xLogin: "xLogin"
        case .instagramLogin: "instagramLogin"
        case .petalBuilder: "petalBuilder"
        }
    }
}

struct AddFeedView: View {

    @Environment(FeedManager.self) var feedManager

    var initialURL: String = ""

    @State private var activeSheet: AddFeedSheetDestination?

    var body: some View {
        AddFeedForm(initialURL: initialURL, activeSheet: $activeSheet)
            .interactiveDismissDisabled()
            .sheet(item: $activeSheet) { destination in
                switch destination {
                case .xLogin:
                    XLoginView()
                case .instagramLogin:
                    InstagramLoginView()
                case .petalBuilder(let seedURL):
                    PetalBuilderView(mode: .create(initialURL: seedURL))
                        .environment(feedManager)
                }
            }
    }
}
