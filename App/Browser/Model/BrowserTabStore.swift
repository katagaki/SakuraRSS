import EnhancedNavigation
import Hanami
import SwiftUI

typealias BrowserTabStore = TabNavigationStore<BrowserLocation, BrowserPageIdentity>
typealias BrowserTab = NavigationTab<BrowserLocation, BrowserPageIdentity>
typealias BrowserOverlayPage = OverlayPage<BrowserPageIdentity>

extension TabStoreConfiguration {
    static let browser = TabStoreConfiguration(
        persistenceKeyPrefix: "Browser",
        snapshotDirectoryName: "BrowserTabSnapshots"
    )
}

extension TabNavigationStore where Root == BrowserLocation, Identity == BrowserPageIdentity {

    static func restored() -> BrowserTabStore {
        restored(configuration: .browser)
    }

    /// Stops at the first page whose row has gone, since anything deeper was
    /// reached through it.
    func restorePathIfNeeded(for tabID: UUID, in feedManager: FeedManager) {
        restorePathIfNeeded(for: tabID) { token, path in
            token.append(to: &path, in: feedManager)
        }
    }

    /// Feed identifiers ordered by how often this browser has opened them.
    var frequentlyVisitedFeedIDs: [Int64] {
        frequentlyVisitedRoots.compactMap { root in
            guard case .feed(let feedID) = root else { return nil }
            return feedID
        }
    }
}
