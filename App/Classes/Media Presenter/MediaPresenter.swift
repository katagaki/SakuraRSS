import SwiftUI

/// Routes podcast and YouTube article taps to a single player sheet at the
/// root tab view. Views deep in the navigation hierarchy mutate this
/// presenter; `MainTabView` observes it and shows the player sheet.
@MainActor
@Observable
final class MediaPresenter {

    static let shared = MediaPresenter()

    var presentedItem: NowPlayingItem?

    /// When set, `presentYouTube`/`presentPodcast` route to this handler
    /// instead of mutating `presentedItem`. visionOS uses this to open a
    /// detached window per playback request.
    @ObservationIgnored
    var detachedHandler: ((NowPlayingItem) -> Void)?

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
        if let detachedHandler {
            detachedHandler(.youTube(article))
        } else {
            presentedItem = .youTube(article)
        }
    }

    func presentPodcast(_ article: Article) {
        if let detachedHandler {
            detachedHandler(.podcast(article))
        } else {
            presentedItem = .podcast(article)
        }
    }
}
