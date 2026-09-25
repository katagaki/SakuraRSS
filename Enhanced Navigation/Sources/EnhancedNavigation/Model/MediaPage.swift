import Foundation

/// A player page in a tab's stack. Its media outlives the page's view, which
/// is torn down when the tab is evicted, so the store holds on to what it
/// takes to stop the media once the page leaves the stack.
struct MediaPage {
    let depth: Int
    let ownsMedia: @MainActor () -> Bool
    let stop: @MainActor () -> Void
}
