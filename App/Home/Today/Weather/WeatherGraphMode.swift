import Foundation

enum WeatherGraphMode: String, CaseIterable, Identifiable {
    case temperature
    case precipitation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .temperature:
            String(localized: "TodayWeather.Graph.Temperature", table: "Home")
        case .precipitation:
            String(localized: "TodayWeather.Graph.Precipitation", table: "Home")
        }
    }

    var symbol: String {
        switch self {
        case .temperature: "thermometer.medium"
        case .precipitation: "drop"
        }
    }
}
