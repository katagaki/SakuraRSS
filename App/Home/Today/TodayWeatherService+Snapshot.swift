import Foundation
import WeatherKit

extension TodayWeatherService {

    static func makeSnapshot(from weatherData: Weather, regionName: String) -> TodayWeather {
        let current = weatherData.currentWeather
        let today = weatherData.dailyForecast.first
        let cutoff = Date().addingTimeInterval(-1800)
        let hourly = weatherData.hourlyForecast
            .filter { $0.date >= cutoff }
            .prefix(8)
            .map { hour in
                TodayWeatherHour(
                    date: hour.date,
                    temperatureCelsius: hour.temperature.converted(to: .celsius).value,
                    symbolName: hour.symbolName,
                    precipitationChance: hour.precipitationChance
                )
            }
        let alert = weatherData.weatherAlerts?.first.map { alert in
            TodayWeatherAlert(
                summary: alert.summary,
                source: alert.source,
                detailsURL: alert.detailsURL
            )
        }
        let currentCelsius = current.temperature.converted(to: .celsius).value
        return TodayWeather(
            temperatureCelsius: currentCelsius,
            apparentTemperatureCelsius: current.apparentTemperature.converted(to: .celsius).value,
            symbolName: current.symbolName,
            conditionDescription: current.condition.description,
            highCelsius: today?.highTemperature.converted(to: .celsius).value ?? currentCelsius,
            lowCelsius: today?.lowTemperature.converted(to: .celsius).value ?? currentCelsius,
            regionName: regionName,
            hourly: Array(hourly),
            alert: alert,
            fetchedAt: Date()
        )
    }
}
