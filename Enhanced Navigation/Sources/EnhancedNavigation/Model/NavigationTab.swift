import SwiftUI

public struct NavigationTab<Root: TabRoot, Identity: TabPageIdentity>: Identifiable {
    public let id: UUID
    public var root: Root
    public var path: NavigationPath
    /// Last identity the tab reported while it was on screen, kept so a tab
    /// switcher can still label a tab that has since been torn down.
    public var pageIdentity: Identity?

    public init(
        id: UUID = UUID(),
        root: Root = .newTabRoot,
        path: NavigationPath = NavigationPath()
    ) {
        self.id = id
        self.root = root
        self.path = path
        self.pageIdentity = nil
    }

    public var canGoBack: Bool { !path.isEmpty }
}
