import UIKit

public extension TabNavigationStore {

    func setSnapshot(_ image: UIImage?, for tabID: UUID) {
        snapshots[tabID] = image
    }

    func captureSelectedTabSnapshot() {
        guard let image = WindowSnapshotter.captureVisiblePage(width: configuration.snapshotWidth) else { return }
        setSnapshot(image, for: selectedTabID)
        let tabID = selectedTabID
        let archive = snapshotArchive
        // Encoded off the main actor as well as written: JPEG compression of a
        // full-height capture is tens of milliseconds, and this runs on the
        // frame the collapse starts on.
        Task.detached(priority: .utility) {
            guard let data = TabSnapshotArchive.encode(image) else { return }
            archive.write(data, for: tabID)
        }
    }

    /// Reads last session's snapshots back in off the main actor, once.
    func loadPersistedSnapshots() {
        guard !hasLoadedPersistedSnapshots else { return }
        hasLoadedPersistedSnapshots = true
        let tabIDs = tabs.map(\.id)
        let archive = snapshotArchive
        Task {
            let archived = await Task.detached(priority: .utility) {
                archive.load(tabIDs)
            }.value
            for (tabID, image) in archived where snapshots[tabID] == nil {
                setSnapshot(image, for: tabID)
            }
            let kept = Set(tabIDs)
            Task.detached(priority: .background) {
                archive.removeAll(except: kept)
            }
        }
    }
}

extension TabNavigationStore {

    var snapshotArchive: TabSnapshotArchive {
        TabSnapshotArchive(directoryName: configuration.snapshotDirectoryName)
    }

    func discardSnapshot(for tabID: UUID) {
        setSnapshot(nil, for: tabID)
        let archive = snapshotArchive
        Task.detached(priority: .utility) {
            archive.remove(tabID)
        }
    }
}
