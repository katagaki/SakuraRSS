import Foundation
import Hanami

/// Content that's open right now, which cleanup never deletes however old it is.
@MainActor
enum OpenContent {

    /// The app's own feed manager, so cleanup updates what's on screen rather
    /// than a second copy of the data.
    static weak var feedManager: FeedManager?

    /// Content on screen, from hosts that track it, as the Mac's windows do.
    static var onScreenArticleIDs: () -> Set<Int64> = { [] }

    static func articleIDs() -> Set<Int64> {
        var articleIDs = onScreenArticleIDs()
        if let episodeID = AudioPlayer.shared.currentArticleID {
            articleIDs.insert(episodeID)
        }
        if let videoID = YouTubePlayerSession.shared.currentArticle?.id {
            articleIDs.insert(videoID)
        }
        return articleIDs
    }
}
