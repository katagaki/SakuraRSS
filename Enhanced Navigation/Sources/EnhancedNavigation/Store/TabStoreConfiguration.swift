import SwiftUI

public struct TabStoreConfiguration {
    /// Tabs beyond this many are torn down and rebuilt from their stored path
    /// when revisited, so many open tabs do not mean many live stacks.
    public var liveTabLimit: Int

    /// Prefixes every `UserDefaults` key the store writes.
    public var persistenceKeyPrefix: String

    /// Under the caches directory: cheap to rebuild, and no business in a
    /// backup.
    public var snapshotDirectoryName: String

    /// In points: the renderer draws at the display's scale.
    public var snapshotWidth: CGFloat

    /// Long enough for the zoom to read; the default speed pops.
    public var switcherAnimation: Animation

    public var frequentlyVisitedLimit: Int

    public init(
        liveTabLimit: Int = 4,
        persistenceKeyPrefix: String,
        snapshotDirectoryName: String,
        snapshotWidth: CGFloat = 200,
        switcherAnimation: Animation = .smooth(duration: 0.34),
        frequentlyVisitedLimit: Int = 8
    ) {
        self.liveTabLimit = liveTabLimit
        self.persistenceKeyPrefix = persistenceKeyPrefix
        self.snapshotDirectoryName = snapshotDirectoryName
        self.snapshotWidth = snapshotWidth
        self.switcherAnimation = switcherAnimation
        self.frequentlyVisitedLimit = frequentlyVisitedLimit
    }
}
