import Observation
import SwiftUI
import Hanami

/// Editing state for the address field. The field itself lives in the bottom
/// toolbar so it gets the system's glass, while the suggestions render in an
/// overlay above it, so both need to read the same text.
@MainActor
@Observable
final class BrowserOmniboxModel {

    /// Used opening and closing alike: closing used to skip the animation,
    /// so the overlay vanished instead of fading.
    static let transition: Animation = .smooth(duration: 0.25)

    var text: String = ""
    var contentMatches: [Article] = []
    private(set) var isActive: Bool = false

    func activate(with query: String = "") {
        text = query
        contentMatches = []
        isActive = true
    }

    func deactivate() {
        isActive = false
        text = ""
        contentMatches = []
    }
}
