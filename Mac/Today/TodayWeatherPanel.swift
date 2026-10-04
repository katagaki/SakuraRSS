import SwiftUI

/// The Mac's weather card, built from the same header, hourly forecast and
/// graph iOS uses.
struct TodayWeatherPanel: View {

    @Bindable var weatherService: TodayWeatherService = .shared
    @AppStorage("Today.Weather.GraphMode") private var graphMode: WeatherGraphMode = .temperature
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let weather = weatherService.weather {
            card(weather)
                .background {
                    ZStack {
                        Rectangle().fill(.quinary)
                        tint(weather)
                    }
                }
                .clipShape(.rect(cornerRadius: 14))
                .contextMenu {
                    Picker(selection: $graphMode) {
                        ForEach(WeatherGraphMode.allCases) { mode in
                            Label(mode.title, systemImage: mode.symbol).tag(mode)
                        }
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.inline)
                }
        }
    }

    private func card(_ weather: TodayWeather) -> some View {
        ZStack {
            TodayWeatherGraph(
                values: graphValues(weather),
                lowerBound: graphBounds(weather).lower,
                upperBound: graphBounds(weather).upper,
                color: graphMode == .precipitation ? .blue : baseColor(weather)
            )
            VStack(alignment: .leading, spacing: 8) {
                if let alert = weather.alert {
                    TodayWeatherAlertBanner(alert: alert)
                    Divider()
                }
                TodayWeatherHeader(weather: weather)
                if !weather.hourly.isEmpty {
                    Divider()
                    TodayWeatherHourlyForecastView(hours: weather.hourly, showsTimeLabels: true)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
    }

    private func tint(_ weather: TodayWeather) -> Color {
        if graphMode == .precipitation, weather.alert == nil {
            return .clear
        }
        return baseColor(weather).opacity(colorScheme == .dark ? 0.3 : 0.2)
    }

    private func baseColor(_ weather: TodayWeather) -> Color {
        weather.alert != nil ? .red : WeatherTint.color(for: weather.symbolName)
    }

    private func graphValues(_ weather: TodayWeather) -> [Double] {
        switch graphMode {
        case .temperature: weather.hourly.map(\.temperatureCelsius)
        case .precipitation: weather.hourly.map { $0.precipitationChance * 100 }
        }
    }

    private func graphBounds(_ weather: TodayWeather) -> (lower: Double, upper: Double) {
        switch graphMode {
        case .temperature:
            let temperatures = weather.hourly.map(\.temperatureCelsius)
            return ((temperatures.min() ?? 0) - 5, (temperatures.max() ?? 0) + 5)
        case .precipitation:
            return (0, 100)
        }
    }
}
