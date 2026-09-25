import SwiftUI

public extension TabNavigationStore {

    var displayedOverlayPage: OverlayPage<Identity>? {
        overlayPages[selectedTabID]?.last
    }

    func setOverlayPage(_ page: OverlayPage<Identity>?, id: UUID, for tabID: UUID) {
        var pages = overlayPages[tabID] ?? []
        if let page {
            if let index = pages.firstIndex(where: { $0.id == id }) {
                pages[index] = page
            } else {
                pages.append(page)
            }
        } else {
            pages.removeAll { $0.id == id }
        }
        overlayPages[tabID] = pages.isEmpty ? nil : pages
    }

    func clearOverlayPages(for tabID: UUID) {
        guard overlayPages[tabID] != nil else { return }
        overlayPages[tabID] = nil
    }
}
