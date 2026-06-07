import SwiftUI
import Hanami

struct TodayWeatherHourlyForecastView: View {

    let hours: [TodayWeatherHour]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(hours.enumerated()), id: \.element.id) { index, hour in
                column(for: hour, isFirst: index == 0)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func column(for hour: TodayWeatherHour, isFirst: Bool) -> some View {
        VStack(spacing: 6) {
            Text(isFirst ? nowLabel : hourLabel(hour.date))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Image(systemName: hour.symbolName)
                .symbolVariant(.fill)
                .symbolRenderingMode(.multicolor)
                .font(.body)
                .frame(width: 22)
                .shadow(color: .black.opacity(0.15), radius: 1.5, y: 0.5)
        }
    }

    private var nowLabel: String {
        String(localized: "TodayWeather.Now", table: "Home")
    }

    private func hourLabel(_ date: Date) -> String {
        date.formatted(.dateTime.hour())
    }
}
