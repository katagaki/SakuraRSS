import Foundation
import Hanami

/// Starts an episode on the shared player, preferring a downloaded copy, as
/// iOS's episode view does.
enum PodcastPlayback {

    static func start(_ article: Article, feedManager: FeedManager, player: AudioPlayer = .shared) {
        let playbackURL: URL
        if let localURL = PodcastDownloadManager.shared.localFileURL(for: article.id) {
            playbackURL = localURL
        } else if let audioURLString = article.audioURL, let audioURL = URL(string: audioURLString) {
            playbackURL = audioURL
        } else {
            return
        }
        let feed = feedManager.feed(forArticle: article)
        player.play(
            url: playbackURL,
            articleID: article.id,
            feedID: article.feedID,
            episodeTitle: article.title,
            feedTitle: feed?.title ?? "",
            artworkURL: article.imageURL,
            feedIconURL: feed?.iconURL,
            episodeDuration: article.duration
        )
    }
}
