import AppKit

/// A reference type, since `NSOutlineView` tracks rows by object identity.
final class SidebarNode: NSObject {

    enum Kind {
        case group(title: String)
        case location(BrowserLocation, title: String, symbolName: String, unreadCount: Int)
    }

    let kind: Kind
    let children: [SidebarNode]

    init(_ kind: Kind, children: [SidebarNode] = []) {
        self.kind = kind
        self.children = children
    }

    var identifier: String {
        switch kind {
        case .group(let title): "group:\(title)"
        case .location(let location, _, _, _): location.persistenceToken
        }
    }

    var location: BrowserLocation? {
        if case .location(let location, _, _, _) = kind { return location }
        return nil
    }

    var isGroup: Bool {
        if case .group = kind { return true }
        return false
    }
}
