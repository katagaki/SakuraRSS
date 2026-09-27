import SwiftUI

/// A modifier rather than a read in the bar's body, so opening the omnibox
/// doesn't rebuild every tab's bar on its first frame.
struct BrowserHiddenWhileEditing: ViewModifier {

    @Environment(BrowserOmniboxModel.self) private var omnibox

    func body(content: Content) -> some View {
        content
            .opacity(omnibox.isActive ? 0 : 1)
            .allowsHitTesting(!omnibox.isActive)
            .accessibilityHidden(omnibox.isActive)
    }
}
