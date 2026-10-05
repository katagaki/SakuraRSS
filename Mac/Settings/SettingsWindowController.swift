import AppKit
import Hanami
import SwiftUI

/// The Settings window, laid out like Safari's: a toolbar of sections, each a
/// column of labelled controls, with the window fitting whichever is shown.
final class SettingsWindowController: NSWindowController {

    init(feedManager: FeedManager) {
        let tabs = SettingsTabViewController()
        tabs.tabStyle = .toolbar
        tabs.canPropagateSelectedChildViewControllerTitle = true
        tabs.transitionOptions = [.allowUserInteraction]
        let panes = [
            SettingsTab("Section.Refreshing", "arrow.triangle.2.circlepath") { RefreshingSettingsPane() },
            SettingsTab("Section.Browsing", "book") { BrowsingSettingsPane() },
            SettingsTab("Section.Focus", "moon") { FocusSettingsPane(feedManager: feedManager) },
            SettingsTab("Section.InsightsAndIntelligence", "sparkles") {
                IntelligenceSettingsPane(feedManager: feedManager)
            },
            SettingsTab("Section.Integrations", "puzzlepiece.extension") {
                IntegrationsSettingsPane().environment(feedManager)
            },
            SettingsTab("iCloud", "icloud") { iCloudSettingsPane() },
            SettingsTab("Section.Data", "externaldrive") { DataSettingsPane(feedManager: feedManager) }
        ]
        for pane in panes {
            let hostingController = NSHostingController(rootView: pane.content)
            hostingController.sizingOptions = .intrinsicContentSize
            hostingController.title = String(localized: String.LocalizationValue(pane.titleKey), table: "Settings")
            let item = NSTabViewItem(viewController: hostingController)
            item.label = hostingController.title ?? ""
            item.image = NSImage(systemSymbolName: pane.symbolName, accessibilityDescription: item.label)
            tabs.addTabViewItem(item)
        }
        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        if let first = tabs.tabViewItems.first?.viewController {
            tabs.resize(window, toFit: first, animated: false)
        }
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}

private struct SettingsTab {
    let titleKey: String
    let symbolName: String
    let content: AnyView

    init<Content: View>(
        _ titleKey: String,
        _ symbolName: String,
        @ViewBuilder content: () -> Content
    ) {
        self.titleKey = titleKey
        self.symbolName = symbolName
        self.content = AnyView(content())
    }
}
