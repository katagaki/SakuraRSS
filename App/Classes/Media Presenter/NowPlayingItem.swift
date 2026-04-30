import SwiftUI

/// A single piece of media that can be playing or shown in the player sheet.
/// Lets the `MediaPresenter` and `MiniPlayerAccessoryModifier` deal with one
/// "now playing" concept regardless of whether it's a podcast or YouTube video.
enum NowPlayingItem: Identifiable, Hashable {

    case podcast(Article)
    case youTube(Article)

    var id: String {
        switch self {
        case .podcast(let article): return "podcast-\(article.id)-\(article.url)"
        case .youTube(let article): return "youtube-\(article.id)-\(article.url)"
        }
    }

    var article: Article {
        switch self {
        case .podcast(let article), .youTube(let article):
            return article
        }
    }
}
