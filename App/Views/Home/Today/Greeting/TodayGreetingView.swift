import SwiftUI

struct TodayGreetingView: View {

    @Bindable var weatherService: TodayWeatherService = .shared
    @AppStorage("Onboarding.Completed") private var onboardingCompleted: Bool = false
    private let deloreanClock = DeloreanClock.shared
    @State private var greeting: TodayGreeting = .from(date: Date())
    @State private var showingLocationPicker = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(formattedDate)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                styledGreeting
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            if let weather = weatherService.weather {
                Button {
                    showingLocationPicker = true
                } label: {
                    weatherSection(weather: weather)
                }
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: false)
            } else if onboardingCompleted, !weatherService.isFetching {
                Button {
                    showingLocationPicker = true
                } label: {
                    setLocationPrompt
                }
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: false)
            }
        }
        .onAppear {
            applyClockState()
            weatherService.refreshAuthorizationStatus()
            if onboardingCompleted {
                Task { await weatherService.refreshIfNeeded() }
            }
        }
        .onChange(of: onboardingCompleted) { _, completed in
            if completed {
                Task { await weatherService.refreshIfNeeded() }
            }
        }
        .onChange(of: deloreanClock.virtualMinutes) { _, _ in
            applyClockState()
        }
        .sheet(isPresented: $showingLocationPicker) {
            TodayWeatherLocationSheet()
                .presentationDetents([.large])
        }
    }

    private func applyClockState() {
        greeting = .from(date: deloreanClock.currentDate)
    }

    /// AttributedString avoids the deprecated `Text + Text` concatenation while
    /// still letting the period draw in the accent color inline with wrapping.
    private var styledGreeting: Text {
        var attributed = AttributedString(greeting.text)
        var period = AttributedString(greeting.terminator)
        period.foregroundColor = .accentColor
        attributed.append(period)
        return Text(attributed)
    }

    private var formattedDate: String {
        Date().formatted(
            .dateTime
                .weekday(.wide)
                .month(.wide)
                .day()
        )
    }

    @ViewBuilder
    private var setLocationPrompt: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Image(systemName: "location.slash")
                .symbolRenderingMode(.hierarchical)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(String(localized: "TodayWeather.Location.SetPrompt", table: "Home"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    @ViewBuilder
    private func weatherSection(weather: TodayWeather) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            if !weather.regionName.isEmpty {
                Text(weather.regionName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
            HStack(spacing: 6) {
                Image(systemName: weather.symbolName)
                    .symbolRenderingMode(.multicolor)
                    .font(.title3)
                Text(temperatureText(weather.temperatureCelsius))
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .fixedSize()
                    .contentTransition(.numericText())
            }
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
