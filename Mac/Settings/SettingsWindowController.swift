import AppKit
import Hanami
import SwiftUI

/// The Settings window, with a tab per section of iOS's settings that
/// applies on the Mac.
final class SettingsWindowController: NSWindowController {

    init(feedManager: FeedManager) {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.canPropagateSelectedChildViewControllerTitle = true
        let panes = [
            SettingsTab("Section.Refreshing", "arrow.triangle.2.circlepath") { FetchingSettingsView() },
            SettingsTab("Section.Browsing", "book.fill") { BrowsingSettingsView() },
            SettingsTab("Section.Focus", "moon.fill") { FocusSettingsView() },
            SettingsTab("Section.InsightsAndIntelligence", "sparkles") { OnDeviceIntelligenceSettingsView() },
            SettingsTab("Section.Data", "externaldrive.fill") { DataSettingsView() }
        ]
        for pane in panes {
            let view = SettingsPane(feedManager: feedManager) { pane.content }
            let hostingController = NSHostingController(rootView: view)
            hostingController.sizingOptions = []
            hostingController.preferredContentSize = SettingsPane<EmptyView>.size
            hostingController.title = String(localized: pane.titleKey, table: "Settings")
            let item = NSTabViewItem(viewController: hostingController)
            item.label = String(localized: pane.titleKey, table: "Settings")
            item.image = NSImage(systemSymbolName: pane.symbolName, accessibilityDescription: item.label)
            tabs.addTabViewItem(item)
        }
        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}

private struct SettingsTab {
    let titleKey: String.LocalizationValue
    let symbolName: String
    let content: AnyView

    init<Content: View>(
        _ titleKey: String.LocalizationValue,
        _ symbolName: String,
        @ViewBuilder content: () -> Content
    ) {
        self.titleKey = titleKey
        self.symbolName = symbolName
        self.content = AnyView(content())
    }
}
