import Foundation

enum SidebarDestination: Hashable {
    case allArticles
    case section(FeedSection)
    case bookmarks
    case topics
    case people
    case list(FeedList)
    case feed(Feed)
    case more
}
