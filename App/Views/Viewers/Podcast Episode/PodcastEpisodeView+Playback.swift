import SwiftUI

extension PodcastEpisodeView {

    func startPlayback() {
        let playbackURL: URL
        if let localURL = downloadManager.localFileURL(for: article.id) {
            playbackURL = localURL
        } else if let audioURLString = article.audioURL,
                  let audioURL = URL(string: audioURLString) {
            playbackURL = audioURL
        } else {
            return
        }
        let feed = feedManager.feed(forArticle: article)
        audioPlayer.play(
            url: playbackURL,
            articleID: article.id,
            feedID: article.feedID,
            episodeTitle: article.title,
            feedTitle: feed?.title ?? "",
            artworkURL: article.imageURL,
            feedIconURL: feed?.faviconURL,
            episodeDuration: article.duration
        )
    }
}
