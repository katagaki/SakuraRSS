import SwiftUI

struct WeatherToolbarButton: View {

    @Binding var isLocationPickerPresented: Bool
    private let weatherService = TodayWeatherService.shared
    @AppStorage("Onboarding.Completed") private var onboardingCompleted: Bool = false

    var body: some View {
        if let weather = weatherService.weather {
            Button {
                isLocationPickerPresented = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: weather.symbolName)
                        .symbolRenderingMode(.multicolor)
                    Text(temperatureText(weather.temperatureCelsius))
                        .fontWeight(.semibold)
                        .contentTransition(.numericText())
                }
                .fixedSize()
            }
            .buttonStyle(.plain)
        } else if onboardingCompleted, !weatherService.isFetching {
            Button {
                isLocationPickerPresented = true
            } label: {
                Image(systemName: "location.slash")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("TodayWeather.Location.SetPrompt"))
            }
            .buttonStyle(.plain)
        }
    }

    private func temperatureText(_ celsius: Double) -> String {
        let rounded = celsius.rounded()
        let measurement = Measurement(value: rounded, unit: UnitTemperature.celsius)
        return measurement.formatted(
            .measurement(
                width: .narrow,
                usage: .weather,
                numberFormatStyle: .number.precision(.fractionLength(0))
            )
        )
    }
}
