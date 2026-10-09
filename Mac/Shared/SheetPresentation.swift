import AppKit
import Hanami
import SwiftUI

extension NSViewController {

    /// Presents a SwiftUI view, such as one of the shared iOS sheets, as a
    /// sheet on this view controller's window.
    func presentSwiftUISheet<Content: View>(_ content: Content, feedManager: FeedManager) {
        presentHostedSheet(
            content
                .environment(feedManager)
                .formStyle(.grouped)
                .frame(minWidth: 560, minHeight: 560)
        )
    }

    /// Presents a SwiftUI view as a sheet whose `@SheetDismiss` action closes it.
    func presentHostedSheet<Content: View>(_ content: Content) {
        let sheet = NSHostingController(rootView: AnyView(EmptyView()))
        sheet.rootView = AnyView(
            content.environment(\.hostedSheetDismissAction, SheetDismissAction { [weak sheet] in
                sheet?.dismiss(nil)
            })
        )
        // Shared sheets set no window title, which macOS shows as "Untitled".
        sheet.title = ""
        presentAsSheet(sheet)
    }
}
