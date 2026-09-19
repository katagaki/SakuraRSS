import Foundation
import SwiftUI

private struct BrowserTabIDKey: EnvironmentKey {
    static let defaultValue: UUID? = nil
}

extension EnvironmentValues {
    /// Which tab's stack a page belongs to. Every mounted tab builds its own
    /// chrome, so a page needs this to tell whether it is the one on screen.
    var browserTabID: UUID? {
        get { self[BrowserTabIDKey.self] }
        set { self[BrowserTabIDKey.self] = newValue }
    }
}
