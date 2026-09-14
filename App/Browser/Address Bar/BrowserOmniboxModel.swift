import Observation
import Hanami

/// Editing state for the address field. The field itself lives in the bottom
/// toolbar so it gets the system's glass, while the suggestions render in an
/// overlay above it, so both need to read the same text.
@MainActor
@Observable
final class BrowserOmniboxModel {

    var text: String = ""
    var contentMatches: [Article] = []
    private(set) var isActive: Bool = false

    func activate() {
        text = ""
        contentMatches = []
        isActive = true
    }

    func deactivate() {
        isActive = false
        text = ""
        contentMatches = []
    }
}
