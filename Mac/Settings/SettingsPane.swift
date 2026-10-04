import AppKit
import Hanami
import SwiftUI

/// One tab of the Settings window: an iOS settings page, with room for the
/// pages it links to.
struct SettingsPane<Content: View>: View {

    static var size: NSSize { NSSize(width: 620, height: 560) }

    let feedManager: FeedManager
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationStack {
            content()
        }
        .environment(feedManager)
        .frame(width: Self.size.width, height: Self.size.height)
    }
}
