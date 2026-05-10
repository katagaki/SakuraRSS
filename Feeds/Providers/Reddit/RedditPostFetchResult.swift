import Foundation

enum RedditPostFetchResult: Sendable {
    case markerString(String)
    case linkedArticle(URL)
}
