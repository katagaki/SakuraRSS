import SwiftUI

struct TodayGreetingView: View {

    @Bindable var weatherService: TodayWeatherService = .shared
    @AppStorage("Onboarding.Completed") private var onboardingCompleted: Bool = false
    private let deloreanClock = DeloreanClock.shared
    @State private var greeting: TodayGreeting = .from(date: Date())

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(formattedDate)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            styledGreeting
                .font(UIDevice.current.userInterfaceIdiom == .pad ? .title3 : .largeTitle)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

}
