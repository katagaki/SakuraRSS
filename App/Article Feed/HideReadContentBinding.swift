import SwiftUI
import Hanami

extension FeedManager {

    /// Hidden while Doomscrolling Mode is on, since it forces read content to show.
    func hideReadContentBinding(onPage pageKey: String) -> Binding<Bool>? {
        guard !DoomscrollingMode.isEnabled else { return nil }
        return Binding(
            get: { self.hidesReadContent(onPage: pageKey) },
            set: { self.setHidesReadContent($0, onPage: pageKey) }
        )
    }
}
