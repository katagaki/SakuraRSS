import SwiftUI

/// Routes podcast and YouTube article taps to a sheet at the root tab view.
/// Views deep in the navigation hierarchy mutate this presenter; `MainTabView`
/// observes it and shows the corresponding sheet.
@MainActor
@Observable
final class MediaPresenter {

    static let shared = MediaPresenter()

    var youTubeArticle: Article?
    var podcastArticle: Article?

    private init() {}

    func presentYouTube(_ article: Article) {
        let session = YouTubePlayerSession.shared
        if session.currentArticle?.id != article.id {
            session.clear()
        }
        // Adopt synchronously so the bottom accessory is in the window before
        // the sheet's matched zoom transition tries to anchor against it.
        session.adopt(article: article)
        if session.videoTitle == nil {
            session.videoTitle = article.title
        }
        if session.artworkURL == nil,
           let imageURL = article.imageURL.flatMap(URL.init(string:)) {
            session.artworkURL = imageURL
        }
        podcastArticle = nil
        // Defer the sheet present so the accessory is added to the window in
        // a prior view update; otherwise the matched zoom transition starts
        // from a nil source and falls back.
        if youTubeArticle == nil {
            DispatchQueue.main.async { [weak self] in
                self?.youTubeArticle = article
            }
        } else {
            youTubeArticle = article
        }
    }

    func presentPodcast(_ article: Article) {
        youTubeArticle = nil
        // Same deferral as `presentYouTube`: when the audio mini player isn't
        // yet showing, give the accessory one update tick to land in the
        // window before the sheet's matched zoom transition fires.
        if podcastArticle == nil, AudioPlayer.shared.currentArticleID == nil {
            DispatchQueue.main.async { [weak self] in
                self?.podcastArticle = article
            }
        } else {
            podcastArticle = article
        }
    }
}
