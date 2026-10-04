#if DEBUG
import AppKit

/// `-DebugOpenLocations "allContent,feedSection:youtube"` opens each location
/// token in a new tab of the frontmost window. `-DebugSimulateWeather rain`
/// shows simulated weather, since unsigned builds can't reach WeatherKit.
enum DebugLaunchActions {

    static func perform(with registry: BrowserWindowRegistry) {
        if let style = UserDefaults.standard.string(forKey: "DebugSimulateWeather") {
            TodayWeatherService.shared.simulateCondition(style: style)
        }
        guard let tokens = UserDefaults.standard.string(forKey: "DebugOpenLocations") else { return }
        for token in tokens.split(separator: ",") {
            guard let location = BrowserLocation(persistenceToken: String(token)),
                  let window = registry.controllers.last?.window else { continue }
            registry.openTab(beside: window, history: BrowserHistory(current: location))
        }
    }
}
#endif
