import AppKit
import Hanami
import Observation

/// The data revisions a window's pages update from. While the window is out of
/// sight, as a tab that isn't selected is, changes are held back and delivered
/// as a single update once it's shown again.
@Observable
final class WindowDataRevisions {

    /// Content, feeds, lists, folders and icons.
    private(set) var dataRevision = 0
    /// Read and bookmark state, and unread counts.
    private(set) var readStateRevision = 0
    /// Recently opened content.
    private(set) var recentsRevision = 0

    @ObservationIgnored private var hasPendingData = false
    @ObservationIgnored private var hasPendingReadState = false
    @ObservationIgnored private var hasPendingRecents = false
    @ObservationIgnored private var dataObserver: ChangeObserver?
    @ObservationIgnored private var readStateObserver: ChangeObserver?
    @ObservationIgnored private var recentsObserver: ChangeObserver?
    @ObservationIgnored nonisolated(unsafe) private var occlusionObserver: NSObjectProtocol?
    @ObservationIgnored private weak var window: NSWindow?

    init(feedManager: FeedManager) {
        dataObserver = ChangeObserver {
            _ = (feedManager.dataRevision, feedManager.iconRevision)
            _ = (feedManager.feeds, feedManager.lists, feedManager.bookmarkFolders)
        } onChange: { [weak self] in
            self?.dataDidChange()
        }
        readStateObserver = ChangeObserver {
            _ = feedManager.readMaskRevision
            _ = (feedManager.unreadCounts, feedManager.unreadReelsCounts)
        } onChange: { [weak self] in
            self?.readStateDidChange()
        }
        recentsObserver = ChangeObserver {
            _ = feedManager.recentsRevision
        } onChange: { [weak self] in
            self?.recentsDidChange()
        }
    }

    deinit {
        if let occlusionObserver {
            NotificationCenter.default.removeObserver(occlusionObserver)
        }
    }

    func attach(to window: NSWindow) {
        self.window = window
        occlusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.deliverPendingChangesIfVisible()
            }
        }
    }

    func cancel() {
        dataObserver?.cancel()
        readStateObserver?.cancel()
        recentsObserver?.cancel()
    }

    private var isWindowVisible: Bool {
        guard let window else { return true }
        return window.occlusionState.contains(.visible)
    }

    private func dataDidChange() {
        if isWindowVisible {
            dataRevision += 1
        } else {
            hasPendingData = true
        }
    }

    private func readStateDidChange() {
        if isWindowVisible {
            readStateRevision += 1
        } else {
            hasPendingReadState = true
        }
    }

    private func recentsDidChange() {
        if isWindowVisible {
            recentsRevision += 1
        } else {
            hasPendingRecents = true
        }
    }

    private func deliverPendingChangesIfVisible() {
        guard isWindowVisible else { return }
        if hasPendingData {
            hasPendingData = false
            dataRevision += 1
        }
        if hasPendingReadState {
            hasPendingReadState = false
            readStateRevision += 1
        }
        if hasPendingRecents {
            hasPendingRecents = false
            recentsRevision += 1
        }
    }
}
