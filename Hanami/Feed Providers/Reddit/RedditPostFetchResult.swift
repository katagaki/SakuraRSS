import Foundation

public enum RedditPostFetchResult: Sendable {
    case markerString(String)
    case linkedArticle(URL)
}
