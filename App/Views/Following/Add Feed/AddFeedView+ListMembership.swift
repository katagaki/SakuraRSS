import SwiftUI

extension AddFeedView {

    var addedFeedIDsSet: Set<Int64> {
        Set(addedURLs.compactMap { url in
            feedManager.feeds.first(where: { $0.url == url })?.id
        })
    }

    func toggleListForAddedFeeds(list: FeedList) {
        let feedIDs = addedFeedIDsSet
        let current = listMembership[list.id] ?? []
        if feedIDs.allSatisfy({ current.contains($0) }) {
            for fid in feedIDs {
                if let feed = feedManager.feedsByID[fid] {
                    feedManager.removeFeedFromList(list, feed: feed)
                }
            }
            listMembership[list.id] = current.subtracting(feedIDs)
        } else {
            for fid in feedIDs {
                if let feed = feedManager.feedsByID[fid] {
                    feedManager.addFeedToList(list, feed: feed)
                }
            }
            listMembership[list.id] = current.union(feedIDs)
        }
    }
}
