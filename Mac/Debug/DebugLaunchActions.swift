#if DEBUG
import AppKit

/// `-DebugOpenLocations "allContent,feedSection:youtube"` opens each location
/// token in a new tab of the frontmost window.
enum DebugLaunchActions {

    static func perform(with registry: BrowserWindowRegistry) {
        guard let tokens = UserDefaults.standard.string(forKey: "DebugOpenLocations") else { return }
        for token in tokens.split(separator: ",") {
            guard let location = BrowserLocation(persistenceToken: String(token)),
                  let window = registry.controllers.last?.window else { continue }
            registry.openTab(beside: window, history: BrowserHistory(current: location))
        }
    }
}
#endif
