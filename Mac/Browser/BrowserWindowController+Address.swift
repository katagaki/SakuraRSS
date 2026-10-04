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
        let sheet = NSHostingController(rootView: AnyView(EmptyView()))
        sheet.rootView = AnyView(AddFeedSheet(
            feedManager: feedManager,
            onDone: { [weak sheet] in sheet?.dismiss(nil) },
            session: FeedDiscoverySession(urlString: urlString)
        ))
        contentViewController?.presentAsSheet(sheet)
    }
}
