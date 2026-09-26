import EnhancedNavigation
import Observation
import SwiftUI

/// The progress each tab's visible page has handed the address bar. Controls
/// go through `tabOmniboxAccessory`; progress stays here because it is data
/// the bar draws itself, not a control.
@Observable
final class BrowserPageSlots {

    private(set) var pageProgress: [UUID: BrowserPageSlot<BrowserAddressProgress>] = [:]

    func setSlot(_ report: BrowserPageSlotReport, token: BrowserPathToken?, for tabID: UUID) {
        switch report {
        case .progress(let progress):
            BrowserPageSlot.fill(&pageProgress[tabID], with: progress, from: token)
        }
    }

    func discard(_ tabIDs: [UUID]) {
        for tabID in tabIDs {
            pageProgress[tabID] = nil
        }
    }

    /// The visible page's own progress, and nothing while a page deeper in
    /// the stack is the one working.
    func displayedProgress(for tabID: UUID, in store: BrowserTabStore) -> BrowserAddressProgress? {
        pageProgress[tabID]?.value(forPageAt: store.displayedPathToken(for: tabID))
    }
}
