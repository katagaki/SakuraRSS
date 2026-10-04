import AppKit
import Hanami
import SwiftUI

extension NSViewController {

    /// Presents a SwiftUI view, such as one of the shared iOS sheets, as a
    /// sheet on this view controller's window.
    func presentSwiftUISheet<Content: View>(_ content: Content, feedManager: FeedManager) {
        let sheet = NSHostingController(
            rootView: content
                .environment(feedManager)
                .formStyle(.grouped)
                .frame(minWidth: 560, minHeight: 560)
        )
        // Shared sheets set no window title, which macOS shows as "Untitled".
        sheet.title = ""
        presentAsSheet(sheet)
    }
}
