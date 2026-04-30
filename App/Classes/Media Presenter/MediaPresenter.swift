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
        if YouTubePlayerSession.shared.currentArticle?.id != article.id {
            YouTubePlayerSession.shared.clear()
        }
        podcastArticle = nil
        youTubeArticle = article
    }

    func presentPodcast(_ article: Article) {
        youTubeArticle = nil
        podcastArticle = article
    }
}
