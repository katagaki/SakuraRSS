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
        // Adopt synchronously so the bottom accessory's source view is in the
        // window before the sheet's matched zoom transition fires.
        session.adopt(article: article)
        if session.videoTitle == nil {
            session.videoTitle = article.title
        }
        if session.artworkURL == nil,
           let imageURL = article.imageURL.flatMap(URL.init(string:)) {
            session.artworkURL = imageURL
        }
        podcastArticle = nil
        youTubeArticle = article
    }

    func presentPodcast(_ article: Article) {
        youTubeArticle = nil
        podcastArticle = article
    }
}
