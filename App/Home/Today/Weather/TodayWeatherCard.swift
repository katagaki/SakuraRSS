import SwiftUI
import Hanami

struct TodayWeatherCard: View {

    @Bindable var weatherService: TodayWeatherService = .shared
    @AppStorage("Onboarding.Completed") private var onboardingCompleted: Bool = false
    @AppStorage("Today.Weather.GraphMode") private var graphMode: WeatherGraphMode = .temperature
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if weatherService.lastError != nil {
            EmptyView()
        } else if let weather = weatherService.weather {
            card(weather)
        } else if onboardingCompleted, !weatherService.isFetching {
            setLocationPrompt
        }
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
                    TodayWeatherHourlyForecastView(hours: weather.hourly)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
        .compatibleGlassEffect(in: .rect(cornerRadius: 14), tint: tint(weather))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func tint(_ weather: TodayWeather) -> Color {
        baseColor(weather).opacity(colorScheme == .dark ? 0.3 : 0.2)
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

    private var setLocationPrompt: some View {
        HStack(spacing: 8) {
            Image(systemName: "location.slash")
                .symbolRenderingMode(.hierarchical)
            Text(String(localized: "TodayWeather.Location.SetPrompt", table: "Home"))
                .font(.subheadline)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .compatibleGlassEffect(in: .rect(cornerRadius: 14))
    }
}
