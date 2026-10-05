import AppKit

/// Rebuilds a menu each time it opens, so it reflects the current page.
final class MenuPopulator: NSObject, NSMenuDelegate {

    private let populate: (NSMenu) -> Void

    init(_ populate: @escaping (NSMenu) -> Void) {
        self.populate = populate
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        populate(menu)
    }
}
