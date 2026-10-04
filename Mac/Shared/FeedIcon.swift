import Hanami
import SwiftUI

/// The Mac's stand-in for iOS's `FeedIcon`, so shared views that show feed
/// icons build here too.
struct FeedIcon: View {

    let feed: Feed
    var size: CGFloat = 32
    var cornerRadius: CGFloat = 4
    var showsRefreshProgress: Bool = false

    var body: some View {
        FeedIconView(feed: feed, size: size)
    }
}
