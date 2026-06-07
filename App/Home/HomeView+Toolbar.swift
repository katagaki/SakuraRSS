import SwiftUI
import Hanami

extension HomeView {

    @ViewBuilder
    var homeContent: some View {
        if tabItems.isEmpty {
            homeEmptyState
        } else if isTodaySelected {
            TodayView()
                .transition(.opacity)
        } else {
            HomeSectionView(source: contentSource)
                .environment(
                    \.homeSectionDisplayMenu,
                    usesPhoneTopBarRedesign ? sectionDisplayMenu : nil
                )
                .transition(.opacity)
        }
    }

    var homeEmptyState: some View {
        ContentUnavailableView {
            Label(
                String(localized: "Home.Empty.Title", table: "Home"),
                systemImage: "rectangle.stack.badge.xmark"
            )
        } description: {
            Text(String(localized: "Home.Empty.Description", table: "Home"))
        }
    }

    @ViewBuilder
    var homeTrailingControl: some View {
        if isTodaySelected {
            weatherTrailingControl
        } else if usesPhoneTopBarRedesign {
            sectionDisplayMenuControl
        }
    }

    @ViewBuilder
    var sectionDisplayMenuControl: some View {
        if let binding = sectionDisplayMenu.styleBinding {
            Menu {
                DisplayStylePicker(
                    displayStyle: binding,
                    hasImages: sectionDisplayMenu.hasImages,
                    showTimeline: sectionDisplayMenu.showTimeline,
                    showPodcast: sectionDisplayMenu.showPodcast
                )
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
            }
            .menuActionDismissBehavior(.disabled)
        }
    }

    @ViewBuilder
    var weatherTrailingControl: some View {
        if usesPhoneTopBarRedesign {
            Menu {
                Picker(
                    String(localized: "TodayWeather.Graph", table: "Home"),
                    selection: $weatherGraphMode
                ) {
                    ForEach(WeatherGraphMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.symbol).tag(mode)
                    }
                }
                .pickerStyle(.inline)
                .labelsVisibility(.visible)
                Button {
                    showingWeatherLocationPicker = true
                } label: {
                    Label(
                        String(localized: "TodayWeather.Location.Title", table: "Home"),
                        systemImage: "location"
                    )
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
            }
        } else {
            WeatherToolbarButton(
                isLocationPickerPresented: $showingWeatherLocationPicker
            )
        }
    }

    @ViewBuilder
    var phoneRefreshStatusStrip: some View {
        if usesPhoneTopBarRedesign {
            ZStack {
                if homeRefreshState.hasActiveProgress {
                    HomeRefreshStatusView(
                        state: homeRefreshState,
                        onStop: cancelHomeRefresh,
                        isShowingDetails: $isShowingRefreshingFeedsPopover,
                        refreshingFeedIDs: activeRefreshingFeedIDs,
                        pendingFeedIDs: activePendingFeedIDs
                    )
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.smooth, value: homeRefreshState.hasActiveProgress)
        }
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
        if activeRefreshScopeKey != nil { return true }
        return feedManager.isLoading && feedManager.hasActiveRefreshProgress
    }

    var activeRefreshingFeedIDs: Set<Int64> {
        if let key = activeRefreshScopeKey,
           let scopedState = feedManager.scopedRefreshes[key] {
            return scopedState.refreshingFeedIDs
        }
        return feedManager.refreshingFeedIDs
    }

    var activePendingFeedIDs: [Int64] {
        if let key = activeRefreshScopeKey,
           let scopedState = feedManager.scopedRefreshes[key] {
            return scopedState.pendingFeedIDs
        }
        return feedManager.pendingRefreshFeedIDs
    }

    var principalText: String {
        let scopedState = activeRefreshScopeKey.flatMap { feedManager.scopedRefreshes[$0] }
        if let scopedState, scopedState.isStopping {
            return String(localized: "Refresh.Stopping", table: "Home")
        }
        if feedManager.isStopping, feedManager.hasActiveRefreshProgress {
            return String(localized: "Refresh.Stopping", table: "Home")
        }
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
        case .section(.today):
            return "section.today"
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
