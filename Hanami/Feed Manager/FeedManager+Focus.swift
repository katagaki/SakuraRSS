import Foundation

public extension FeedManager {

    var isFocusActive: Bool {
        activeFocus.isActive && !activeFocus.isEmpty
    }

    /// True only when an active focus actually resolves to at least one feed.
    /// Guards against an unsatisfiable focus (e.g. a focused list was deleted)
    /// hiding everything with no way back.
    var isFocusEffective: Bool {
        isFocusActive && !focusedFeedIDs.isEmpty
    }

    var focusedFeedIDs: Set<Int64> {
        guard isFocusActive else { return Set(feeds.map(\.id)) }
        let revision = dataRevision
        if let cache = focusedFeedIDsCache, cache.revision == revision {
            return cache.ids
        }
        var ids = Set<Int64>()
        for list in lists where activeFocus.listIDs.contains(list.id) {
            ids.formUnion(feedIDs(for: list))
        }
        for feed in feeds where activeFocus.sectionKeys.contains(feed.feedSection.rawValue) {
            ids.insert(feed.id)
        }
        focusedFeedIDsCache = (revision, ids)
        return ids
    }

    func isFeedInFocus(_ feed: Feed) -> Bool {
        guard isFocusActive else { return true }
        return focusedFeedIDs.contains(feed.id)
    }

    func isListInFocus(_ list: FeedList) -> Bool {
        guard isFocusActive else { return true }
        return activeFocus.listIDs.contains(list.id)
    }

    func isSectionInFocus(_ section: FeedSection) -> Bool {
        guard isFocusActive else { return true }
        if activeFocus.sectionKeys.contains(section.rawValue) { return true }
        let focused = focusedFeedIDs
        return feeds.contains { $0.feedSection == section && focused.contains($0.id) }
    }

    func reloadFocusFromDefaults() {
        let loaded = FocusFilterStore.load()
        guard loaded != activeFocus else { return }
        activeFocus = loaded
        bumpDataRevision()
    }
}
