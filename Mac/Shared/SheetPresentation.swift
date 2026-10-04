import AppKit
import Hanami
import SwiftUI

extension NSViewController {

    /// Presents a SwiftUI view, such as one of the shared iOS sheets, as a
    /// sheet on this view controller's window.
    func presentSwiftUISheet<Content: View>(_ content: Content, feedManager: FeedManager) {
        let sheet = NSHostingController(rootView: content.environment(feedManager).frame(minWidth: 480, minHeight: 420))
        presentAsSheet(sheet)
    }
}
