import SwiftUI
import Hanami

/// In-memory home selection, persisted lazily to `UserDefaults`.
///
/// Writing the selection through `@AppStorage` on every tab tap posts a
/// store-wide `UserDefaults` change that invalidates every `@AppStorage`-bearing
/// view (including the Home toolbar host), which re-applies the toolbar and
/// resets the section bar's scroll. Keeping the value in an `@Observable` here
/// means a tap mutates memory only; persistence happens on scene-phase changes.
@MainActor
@Observable
final class HomeSelectionStore {

    var selection: HomeSelection

    private static let storageKey = "Home.SelectedSection"

    init() {
        if let rawValue = UserDefaults.standard.string(forKey: Self.storageKey),
           let restored = HomeSelection(rawValue: rawValue) {
            selection = restored
        } else {
            selection = .section(.today)
        }
    }

    func persist() {
        UserDefaults.standard.set(selection.rawValue, forKey: Self.storageKey)
    }
}
