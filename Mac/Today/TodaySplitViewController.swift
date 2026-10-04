import AppKit
import Hanami
import SwiftUI

/// Today's greeting column beside its card rows, with a divider the user can
/// drag, as iPad lays Today out in landscape.
final class TodaySplitViewController: NSSplitViewController {

    private let leadingViewController: NSHostingController<TodayLeadingColumn>
    private let cardsViewController: NSHostingController<TodayCardsColumn>

    init(feedManager: FeedManager, actions: TodayActions) {
        leadingViewController = NSHostingController(
            rootView: TodayLeadingColumn(feedManager: feedManager, actions: actions)
        )
        cardsViewController = NSHostingController(
            rootView: TodayCardsColumn(model: TodayModel(), feedManager: feedManager, actions: actions)
        )
        leadingViewController.sizingOptions = []
        cardsViewController.sizingOptions = []
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        splitView.dividerStyle = .thin
        let leadingItem = NSSplitViewItem(viewController: leadingViewController)
        leadingItem.minimumThickness = 300
        leadingItem.maximumThickness = 560
        leadingItem.holdingPriority = .defaultLow + 1
        let cardsItem = NSSplitViewItem(viewController: cardsViewController)
        cardsItem.minimumThickness = 340
        addSplitViewItem(leadingItem)
        addSplitViewItem(cardsItem)
        splitView.autosaveName = "TodaySplitView"
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        let savedFramesKey = "NSSplitView Subview Frames \(splitView.autosaveName ?? "")"
        guard UserDefaults.standard.object(forKey: savedFramesKey) == nil else { return }
        splitView.setPosition(400, ofDividerAt: 0)
    }
}
