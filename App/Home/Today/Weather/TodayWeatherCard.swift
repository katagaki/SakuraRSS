import SwiftUI
import Hanami

struct TodayWeatherCard: View {

    @Bindable var weatherService: TodayWeatherService = .shared
    @AppStorage("Today.Weather.GraphMode") private var graphMode: WeatherGraphMode = .temperature
    @Environment(\.colorScheme) private var colorScheme

    let usesFlatBackground: Bool
    let showsHourlyTimeLabels: Bool

    init(usesFlatBackground: Bool = false, showsHourlyTimeLabels: Bool = true) {
        self.usesFlatBackground = usesFlatBackground
        self.showsHourlyTimeLabels = showsHourlyTimeLabels
    }

    var body: some View {
        if let weather = weatherService.weather {
            if usesFlatBackground {
                flatCard(weather)
            } else {
                glassCard(weather)
            }
        }
    }

    private func glassCard(_ weather: TodayWeather) -> some View {
        card(weather)
            .compatibleGlassEffect(in: .rect(cornerRadius: 14), tint: tint(weather))
            .clipShape(.rect(cornerRadius: 14))
    }

    /// Flat-background variant for hosts that already sit on glass,
    /// since stacking glass on glass is not supported.
    private func flatCard(_ weather: TodayWeather) -> some View {
        card(weather)
            .background {
                ZStack {
                    Color(.secondarySystemBackground)
                    if let tintColor = tint(weather) {
                        tintColor
                    }
                }
            }
            .clipShape(.rect(cornerRadius: 14))
    }

    private func card(_ weather: TodayWeather) -> some View {
        ZStack {
            TodayWeatherGraph(
                values: graphValues(weather),
                lowerBound: graphBounds(weather).lower,
                upperBound: graphBounds(weather).upper,
                color: graphColor(weather)
            )
            VStack(alignment: .leading, spacing: 8) {
                if let alert = weather.alert {
                    TodayWeatherAlertBanner(alert: alert)
                    Divider()
                }
                TodayWeatherHeader(weather: weather)
                if !weather.hourly.isEmpty {
                    Divider()
                    TodayWeatherHourlyForecastView(
                        hours: weather.hourly,
                        showsTimeLabels: showsHourlyTimeLabels
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
    }

    private func tint(_ weather: TodayWeather) -> Color? {
        if graphMode == .precipitation {
            guard weather.alert != nil else { return nil }
            return Color.red.opacity(colorScheme == .dark ? 0.3 : 0.2)
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

    private func graphColor(_ weather: TodayWeather) -> Color {
        graphMode == .precipitation ? .blue : baseColor(weather)
    }
}
