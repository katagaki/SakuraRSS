import Hanami

extension BrowserLocation {

    /// The pages that have their own Hide Read Content choice, as on iOS.
    func pageKey(in feedManager: FeedManager) -> String? {
        switch self {
        case .startPage, .allContent:
            ContentPageKey.section(nil)
        case .feedSection(let section):
            ContentPageKey.section(section)
        case .feed(let feedID):
            feedManager.feedsByID[feedID].map(feedManager.pageKey(for:))
        case .list(let listID):
            feedManager.lists.first { $0.id == listID }.map(feedManager.pageKey(for:))
        case .topic(let name):
            ContentPageKey.topic(name)
        case .bookmarks, .search, .article, .bookmarkFolder, .bookmarkTag, .topics, .person, .webPage:
            nil
        }
    }
}
