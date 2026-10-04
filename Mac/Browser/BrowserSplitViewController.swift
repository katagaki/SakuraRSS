import AppKit
import Hanami
import SwiftUI

final class BrowserSplitViewController: NSSplitViewController {

    let feedManager: FeedManager
    let sidebarViewController: SidebarViewController
    private let locationViewController: NSHostingController<LocationPlaceholderView>

    init(feedManager: FeedManager) {
        self.feedManager = feedManager
        sidebarViewController = SidebarViewController(feedManager: feedManager)
        locationViewController = NSHostingController(
            rootView: LocationPlaceholderView(title: "", symbolName: "newspaper")
        )
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarViewController)
        sidebarItem.minimumThickness = 200
        sidebarItem.maximumThickness = 360
        sidebarItem.canCollapse = true
        let locationItem = NSSplitViewItem(viewController: locationViewController)
        locationItem.minimumThickness = 420
        addSplitViewItem(sidebarItem)
        addSplitViewItem(locationItem)
        splitView.autosaveName = "BrowserSplitView"
    }

    func show(_ location: BrowserLocation) {
        sidebarViewController.select(location)
        locationViewController.rootView = LocationPlaceholderView(
            title: location.title(in: feedManager),
            symbolName: location.symbolName(in: feedManager)
        )
    }
}
