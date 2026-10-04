import SwiftUI

struct TodayHeader: View {

    let isCompact: Bool
    private let weatherService = TodayWeatherService.shared

    var body: some View {
        TimelineView(.everyMinute) { context in
            VStack(alignment: .leading, spacing: 2) {
                Text(context.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text(TodayGreeting.text(at: context.date))
                    .font(isCompact ? .title : .largeTitle)
                    .fontWeight(.bold)
                TodayWeatherPanel(showsHourlyTimeLabels: !isCompact)
                    .padding(.top, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            weatherService.refreshAuthorizationStatus()
            await weatherService.refreshIfNeeded()
        }
    }
}
