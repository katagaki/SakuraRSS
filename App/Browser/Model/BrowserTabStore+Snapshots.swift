import UIKit

extension BrowserTabStore {

    func captureSelectedTabSnapshot() {
        guard let image = BrowserTabSnapshotter.captureVisiblePage() else { return }
        setSnapshot(image, for: selectedTabID)
        guard let data = BrowserSnapshotArchive.encode(image) else { return }
        let tabID = selectedTabID
        Task.detached(priority: .utility) {
            BrowserSnapshotArchive.write(data, for: tabID)
        }
    }

    /// Reads last session's snapshots back in off the main actor, so a switcher
    /// opened straight after launch is not the only one with empty cards.
    func loadPersistedSnapshots() {
        let tabIDs = tabs.map(\.id)
        Task {
            let archived = await Task.detached(priority: .utility) {
                BrowserSnapshotArchive.load(tabIDs)
            }.value
            for (tabID, data) in archived where snapshots[tabID] == nil {
                setSnapshot(UIImage(data: data), for: tabID)
            }
            let kept = Set(tabIDs)
            Task.detached(priority: .background) {
                BrowserSnapshotArchive.removeAll(except: kept)
            }
        }
    }

    func discardSnapshot(for tabID: UUID) {
        setSnapshot(nil, for: tabID)
        Task.detached(priority: .utility) {
            BrowserSnapshotArchive.remove(tabID)
        }
    }
}
