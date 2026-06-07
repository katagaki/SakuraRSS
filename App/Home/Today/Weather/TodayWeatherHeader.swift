import SwiftUI
import Hanami

struct TodayWeatherHeader: View {

    let weather: TodayWeather

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !weather.regionName.isEmpty {
                Text(weather.regionName)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .center) {
                HStack(alignment: .center, spacing: 8) {
                    Text(WeatherTemperatureFormat.degrees(weather.temperatureCelsius))
                        .font(.system(size: 42))
                        .contentTransition(.numericText())
                    Image(systemName: weather.symbolName)
                        .symbolVariant(.fill)
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 28))
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    highLow(label: highLabel, celsius: weather.highCelsius)
                    highLow(label: lowLabel, celsius: weather.lowCelsius)
                }
            }
            Text(conditionLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
