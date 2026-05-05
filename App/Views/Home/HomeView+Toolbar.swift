import SwiftUI

extension HomeView {

    @ViewBuilder
    var weatherToolbarButton: some View {
        if let weather = weatherService.weather {
            Button {
                showingWeatherLocationPicker = true
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
                showingWeatherLocationPicker = true
            } label: {
                Image(systemName: "location.slash")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("TodayWeather.Location.SetPrompt"))
            }
            .buttonStyle(.plain)
        }
    }

    func temperatureText(_ celsius: Double) -> String {
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

    var principalToolbarLabel: some View {
        Button {
            if isShowingRefreshProgress {
                isShowingRefreshingFeedsPopover = true
            }
        } label: {
            principalLabelText
        }
        .buttonStyle(.plain)
        .contentShape(.rect)
        .popover(isPresented: $isShowingRefreshingFeedsPopover) {
            RefreshingFeedsPopoverView(
                refreshingFeedIDs: activeRefreshingFeedIDs,
                pendingFeedIDs: activePendingFeedIDs
            )
            .environment(feedManager)
            .presentationCompactAdaptation(.popover)
        }
        .onChange(of: isShowingRefreshProgress) { _, isShowing in
            if !isShowing { isShowingRefreshingFeedsPopover = false }
        }
    }

    var principalLabelText: some View {
        Text(principalText)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.vertical, 4)
    }

    var isShowingRefreshProgress: Bool {
        if let scopedState = feedManager.scopedRefreshes[currentScopeKey],
           scopedState.hasActiveProgress {
            return true
        }
        return feedManager.isLoading && feedManager.hasActiveRefreshProgress
    }

    var activeRefreshingFeedIDs: Set<Int64> {
        if let scopedState = feedManager.scopedRefreshes[currentScopeKey],
           scopedState.hasActiveProgress {
            return scopedState.refreshingFeedIDs
        }
        return feedManager.refreshingFeedIDs
    }

    var activePendingFeedIDs: [Int64] {
        if let scopedState = feedManager.scopedRefreshes[currentScopeKey],
           scopedState.hasActiveProgress {
            return scopedState.pendingFeedIDs
        }
        return feedManager.pendingRefreshFeedIDs
    }

    var principalText: String {
        let scopedState = feedManager.scopedRefreshes[currentScopeKey]
        if let scopedState, scopedState.hasActiveProgress {
            return String(
                localized: "Home.Refreshing \(scopedState.completed) \(scopedState.total)",
                table: "Home"
            )
        }
        if feedManager.isLoading && feedManager.hasActiveRefreshProgress {
            return String(
                localized: "Home.Refreshing \(feedManager.refreshCompleted) \(feedManager.refreshTotal)",
                table: "Home"
            )
        }
        return formattedDate
    }

    var currentScopeKey: String {
        switch selectedSelection {
        case .section(let section):
            if let feedSection = section.feedSection {
                return "section.\(feedSection.rawValue)"
            }
            return "section.all"
        case .list(let id):
            return "list.\(id)"
        case .topic(let name):
            return "topic.\(name)"
        }
    }

    var formattedDate: String {
        let relative: String
        let scopedDate = feedManager.scopedLastRefreshedAt[currentScopeKey]
        if let date = scopedDate ?? feedManager.lastRefreshedAt {
            relative = date.formatted(.relative(presentation: .named))
        } else {
            relative = Date().formatted(
                .dateTime
                    .weekday(.wide)
                    .month(.abbreviated)
                    .day()
            )
        }
        return String(localized: "Home.LastUpdated \(relative)", table: "Home")
    }
}
