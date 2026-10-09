import AppKit
import SwiftUI

extension BrowserWindowController {

    func commitAddress(_ kind: AddressSuggestion.Kind) {
        switch kind {
        case .location(let location):
            navigate(to: location)
        case .searchContent(let query):
            navigate(to: .search(query))
        case .discoverFeeds(let urlString):
            presentAddFeedSheet(for: urlString)
        }
    }

    func presentAddFeedSheet(for urlString: String) {
        contentViewController?.presentHostedSheet(AddFeedSheet(
            feedManager: feedManager,
            session: FeedDiscoverySession(urlString: urlString)
        ))
    }
}
