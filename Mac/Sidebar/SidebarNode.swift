import AppKit

/// A reference type, since `NSOutlineView` tracks rows by object identity.
final class SidebarNode: NSObject {

    enum Kind {
        case group(title: String)
        case location(BrowserLocation, title: String, symbolName: String, unreadCount: Int)
    }

    private(set) var kind: Kind
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

extension SidebarNode {

    /// Moves the titles and counts of `rebuilt` onto these nodes when the tree's
    /// shape is unchanged, so the outline keeps its rows instead of reloading.
    static func adoptKinds(from rebuilt: [SidebarNode], into existing: [SidebarNode]) -> Bool {
        guard hasSameShape(rebuilt, existing) else { return false }
        copyKinds(from: rebuilt, into: existing)
        return true
    }

    private static func hasSameShape(_ first: [SidebarNode], _ second: [SidebarNode]) -> Bool {
        guard first.count == second.count else { return false }
        return zip(first, second).allSatisfy { pair in
            pair.0.identifier == pair.1.identifier && hasSameShape(pair.0.children, pair.1.children)
        }
    }

    private static func copyKinds(from rebuilt: [SidebarNode], into existing: [SidebarNode]) {
        for (source, destination) in zip(rebuilt, existing) {
            destination.kind = source.kind
            copyKinds(from: source.children, into: destination.children)
        }
    }
}
