import Hanami
import SwiftUI

/// The Mac's stand-in for iOS's `ArticleDetailView`, used by the shared edit
/// feed sheet's viewer preview.
struct ArticleDetailView: View {

    let article: Article
    var previewMode = false
    @State private var activity = BrowserPageActivity()
    @Environment(FeedManager.self) private var feedManager

    var body: some View {
        ReaderView(article: article, feed: nil, activity: activity, feedManager: feedManager, isPreview: previewMode)
    }
}
