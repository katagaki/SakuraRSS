import Foundation

public extension FeedManager {

    func setBookmarkCustomTitle(_ title: String?, forArticleID articleID: Int64) {
        try? database.setCustomTitle(title, forArticleID: articleID)
        bumpDataRevision()
    }
}
