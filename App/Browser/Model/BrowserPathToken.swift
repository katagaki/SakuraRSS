import Foundation
import Hanami
import SwiftUI

/// One pushed destination, stored by identifier rather than by value so a
/// tab's stack can be rebuilt from the database on the next launch instead of
/// archiving live rows that may since have been refreshed away.
enum BrowserPathToken: Codable, Hashable {
    case location(String)
    case feed(Int64)
    case article(Int64)
    case entity(name: String, types: [String])
    case headline(title: String, articleIDs: [Int64])
    case bookmarks

    /// Appends the destination this token stands for. Returns false when the
    /// row behind it is gone, which ends the rebuild: anything deeper was
    /// reached through this page and would be stranded without it.
    @MainActor
    func append(to path: inout NavigationPath, in feedManager: FeedManager) -> Bool {
        switch self {
        case .location(let token):
            guard let location = BrowserLocation.resolve(token: token) else { return false }
            path.append(location)
        case .feed(let feedID):
            guard let feed = feedManager.feedsByID[feedID] else { return false }
            path.append(feed)
        case .article(let articleID):
            guard let article = feedManager.article(byID: articleID) else { return false }
            path.append(article)
        case .entity(let name, let types):
            path.append(EntityDestination(name: name, types: types))
        case .headline(let title, let articleIDs):
            path.append(SummaryHeadlineDestination(title: title, articleIDs: articleIDs))
        case .bookmarks:
            path.append(BrowserBookmarksDestination())
        }
        return true
    }
}

private struct BrowserPathTokenKey: EnvironmentKey {
    static let defaultValue: BrowserPathToken? = nil
}

extension EnvironmentValues {
    /// Set by the destination that pushed the page, so the page's reported
    /// identity carries what it would take to push it again.
    var browserPathToken: BrowserPathToken? {
        get { self[BrowserPathTokenKey.self] }
        set { self[BrowserPathTokenKey.self] = newValue }
    }
}
