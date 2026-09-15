import SwiftUI

extension View {
    /// Hides the page's own bottom bar while the tab switcher owns the chrome.
    func browserPageBarHidden(_ isHidden: Bool) -> some View {
        #if os(visionOS)
        self
        #else
        toolbarVisibility(isHidden ? .hidden : .automatic, for: .bottomBar)
        #endif
    }
}
