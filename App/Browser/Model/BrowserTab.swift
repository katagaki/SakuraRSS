import Foundation
import SwiftUI

struct BrowserTab: Identifiable {
    let id: UUID
    var location: BrowserLocation
    var path: NavigationPath
    /// Last title the tab reported while it was on screen, kept so the tab
    /// switcher can still label a tab that has since been torn down.
    var pageIdentity: BrowserPageIdentity?

    init(
        id: UUID = UUID(),
        location: BrowserLocation = .startPage,
        path: NavigationPath = NavigationPath()
    ) {
        self.id = id
        self.location = location
        self.path = path
        self.pageIdentity = nil
    }

    var canGoBack: Bool { !path.isEmpty }
}
