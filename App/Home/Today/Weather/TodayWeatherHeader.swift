import SwiftUI
import Hanami

struct TodayWeatherHeader: View {

    let weather: TodayWeather

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(WeatherTemperatureFormat.degrees(weather.temperatureCelsius))
                        .font(.system(size: 42, weight: .light))
                        .contentTransition(.numericText())
                    Image(systemName: weather.symbolName)
                        .symbolRenderingMode(.multicolor)
                        .font(.title2)
                }
                Text(conditionLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                highLow(label: highLabel, celsius: weather.highCelsius)
                highLow(label: lowLabel, celsius: weather.lowCelsius)
            }
        }
    }

    private func highLow(label: String, celsius: Double) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(WeatherTemperatureFormat.degrees(celsius))
                .font(.callout)
                .fontWeight(.semibold)
        }
    }

    private var conditionLine: String {
        let feels = String(localized: "TodayWeather.FeelsLike", table: "Home")
        let apparent = WeatherTemperatureFormat.degrees(weather.apparentTemperatureCelsius)
        return "\(weather.conditionDescription) · \(feels) \(apparent)"
    }

    private var highLabel: String {
        String(localized: "TodayWeather.High", table: "Home")
    }

    private var lowLabel: String {
        String(localized: "TodayWeather.Low", table: "Home")
    }
}
