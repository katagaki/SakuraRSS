#if os(visionOS)
import SwiftUI

struct DetachedYouTubePlayerWindow: View {

    @Environment(FeedManager.self) private var feedManager
    let articleID: Int64?

    var body: some View {
        if let articleID, let article = feedManager.article(byID: articleID) {
            NavigationStack {
                YouTubePlayerView(article: article, showsDismissButton: false)
            }
        } else {
            ProgressView()
        }
    }
}

struct DetachedPodcastPlayerWindow: View {

    @Environment(FeedManager.self) private var feedManager
    let articleID: Int64?

    var body: some View {
        if let articleID, let article = feedManager.article(byID: articleID) {
            NavigationStack {
                PodcastEpisodeView(article: article, showsDismissButton: false)
            }
        } else {
            ProgressView()
        }
    }
}
#endif
