import UIKit

extension BrowserTabStore {

    func captureSelectedTabSnapshot() {
        guard let image = BrowserTabSnapshotter.captureVisiblePage() else { return }
        setSnapshot(image, for: selectedTabID)
        let tabID = selectedTabID
        // Encoded off the main actor as well as written: JPEG compression of a
        // full-height capture is tens of milliseconds, and this runs on the
        // frame the collapse starts on.
        Task.detached(priority: .utility) {
            guard let data = BrowserSnapshotArchive.encode(image) else { return }
            BrowserSnapshotArchive.write(data, for: tabID)
        }
    }

    /// Reads last session's snapshots back in off the main actor.
    func loadPersistedSnapshots() {
        let tabIDs = tabs.map(\.id)
        Task {
            let archived = await Task.detached(priority: .utility) {
                BrowserSnapshotArchive.load(tabIDs)
            }.value
            for (tabID, image) in archived where snapshots[tabID] == nil {
                setSnapshot(image, for: tabID)
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
