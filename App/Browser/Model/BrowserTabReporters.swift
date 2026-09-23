import Foundation

/// Built once per tab: a closure made in `body` is new on every pass, and a
/// new closure in the environment invalidates every page that reads it.
@MainActor
struct BrowserTabReporters {
    let page: (BrowserPageIdentity) -> Void
    let overlayPage: (UUID, BrowserOverlayPage?) -> Void
    let slot: (BrowserPageSlotReport, BrowserPathToken?) -> Void

    init(store: BrowserTabStore, tabID: UUID) {
        page = { identity in
            store.setPageIdentity(identity, for: tabID)
        }
        overlayPage = { overlayID, page in
            store.setOverlayPage(page, id: overlayID, for: tabID)
        }
        slot = { report, token in
            store.setSlot(report, token: token, for: tabID)
        }
    }
}
