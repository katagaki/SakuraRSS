import Foundation

extension TodayWeatherService {

    func simulateAlert() {
        var snapshot = weather ?? Self.simulationPlaceholder()
        snapshot.alert = TodayWeatherAlert(
            summary: "気象特別警報：台風○号",
            source: "気象庁",
            detailsURL: URL(string: "sakura://")
        )
        snapshot.fetchedAt = Date()
        weather = snapshot
        lastError = nil
    }

    func simulateCondition(style: String?) {
        let condition = Self.simulatedCondition(for: style)
        var snapshot = weather ?? Self.simulationPlaceholder()
        snapshot.symbolName = condition.symbol
        snapshot.conditionDescription = condition.description
        snapshot.hourly = snapshot.hourly.map { hour in
            var copy = hour
            copy.symbolName = condition.symbol
            return copy
        }
        snapshot.fetchedAt = Date()
        weather = snapshot
        lastError = nil
    }

    private static func simulatedCondition(for style: String?) -> (symbol: String, description: String) {
        switch style?.lowercased() {
        case "clear", "sunny", "sun":
            return ("sun.max.fill", "Clear")
        case "night", "clear-night":
            return ("moon.stars.fill", "Clear")
        case "cloudy", "clouds", "overcast":
            return ("cloud.fill", "Cloudy")
        case "partlycloudy", "partly-cloudy":
            return ("cloud.sun.fill", "Partly Cloudy")
        case "rain", "rainy", "drizzle":
            return ("cloud.rain.fill", "Rain")
        case "snow", "snowy", "sleet":
            return ("cloud.snow.fill", "Snow")
        case "thunderstorm", "storm", "thunder", "bolt":
            return ("cloud.bolt.rain.fill", "Thunderstorms")
        case "wind", "windy":
            return ("wind", "Windy")
        case "fog", "foggy", "haze", "mist":
            return ("cloud.fog.fill", "Fog")
        default:
            return ("cloud.sun.fill", "Partly Cloudy")
        }
    }

    private static func simulationPlaceholder() -> TodayWeather {
        let now = Date()
        let temperatures: [Double] = [11, 12, 13, 14, 14, 13, 12, 11]
        let hourly = temperatures.enumerated().map { index, temperature in
            TodayWeatherHour(
                date: now.addingTimeInterval(Double(index) * 3600),
                temperatureCelsius: temperature,
                symbolName: "cloud.sun.fill",
                precipitationChance: 0
            )
        }
        return TodayWeather(
            temperatureCelsius: 11,
            apparentTemperatureCelsius: 9,
            symbolName: "cloud.sun.fill",
            conditionDescription: "Partly Cloudy",
            highCelsius: 16,
            lowCelsius: 9,
            regionName: "Simulated",
            hourly: hourly,
            alert: nil,
            fetchedAt: now
        )
    }
}
