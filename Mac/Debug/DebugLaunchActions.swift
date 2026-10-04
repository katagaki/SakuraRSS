#if DEBUG
import AppKit

/// `-DebugOpenLocations "allContent,feedSection:youtube"` opens each location
/// token in a new tab of the frontmost window. `-DebugSimulateWeather rain`
/// shows simulated weather, since unsigned builds can't reach WeatherKit.
/// `-DebugOpenSettingsTab 6` opens Settings on that tab, counting from zero.
enum DebugLaunchActions {

    static func perform(with registry: BrowserWindowRegistry) {
        if let style = UserDefaults.standard.string(forKey: "DebugSimulateWeather") {
            TodayWeatherService.shared.simulateCondition(style: style)
        }
        if UserDefaults.standard.object(forKey: "DebugOpenSettingsTab") != nil {
            // After window restoration, so Settings ends up the key window.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                openSettings(at: UserDefaults.standard.integer(forKey: "DebugOpenSettingsTab"))
            }
        }
        guard let tokens = UserDefaults.standard.string(forKey: "DebugOpenLocations") else { return }
        for token in tokens.split(separator: ",") {
            guard let location = BrowserLocation(persistenceToken: String(token)),
                  let window = registry.controllers.last?.window else { continue }
            registry.openTab(beside: window, history: BrowserHistory(current: location))
        }
    }

    private static func openSettings(at index: Int) {
        NSApp.sendAction(#selector(AppDelegate.showSettings(_:)), to: nil, from: nil)
        guard let tabs = NSApp.windows.lazy.compactMap({ $0.contentViewController as? NSTabViewController }).first,
              tabs.tabViewItems.indices.contains(index) else { return }
        tabs.selectedTabViewItemIndex = index
    }
}
#endif
