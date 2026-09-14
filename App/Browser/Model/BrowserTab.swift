import Foundation
import SwiftUI

struct BrowserTab: Identifiable {
    let id: UUID
    var location: BrowserLocation
    /// Locations this tab visited before the current one, so Back walks out of a
    /// feed and onto the start page the way it does in Safari.
    var locationHistory: [BrowserLocation]
    var path: NavigationPath
    /// Last title the tab reported while it was on screen, kept so the tab
    /// switcher can still label a tab that has since been torn down.
    var pageIdentity: BrowserPageIdentity?
    var lastVisited: Date

    init(
        id: UUID = UUID(),
        location: BrowserLocation = .startPage,
        path: NavigationPath = NavigationPath(),
        lastVisited: Date = .now
    ) {
        self.id = id
        self.location = location
        self.locationHistory = []
        self.path = path
        self.pageIdentity = nil
        self.lastVisited = lastVisited
    }

    var canGoBack: Bool { !path.isEmpty || !locationHistory.isEmpty }
}
