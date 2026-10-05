import AppKit

/// What the buttons on a Feed or Compact Feed row do.
struct PostCellActions {
    var open: () -> Void = {}
    var copyLink: () -> Void = {}
    var toggleRead: () -> Void = {}
    var toggleBookmark: () -> Void = {}
    var share: (NSView) -> Void = { _ in }
    var showMenu: (NSView) -> Void = { _ in }
}
