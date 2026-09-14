import SwiftUI

/// Single-column Today layout: greeting and weather, summary cards, then the
/// content sections stacked beneath them.
extension TodayView {

    var portraitLayout: some View {
        let episodes = visibleEpisodes
        let sections = contentSections(episodes: episodes)
        let showEmpty = todayManager.hasLoadedInitially && !anySummaryVisible && sections.isEmpty
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerView

                TodayGreetingView()
                    .padding(.horizontal)

                if isWeatherShowing {
                    sectionDivider
                }

                if !anySummaryVisible, !isWeatherShowing,
                   !todayManager.hasLoadedInitially || !sections.isEmpty || showEmpty {
                    sectionDivider
                }

                if anySummaryActive {
                    summaryCardsStack
                }

                if anySummaryVisible,
                   !todayManager.hasLoadedInitially || !sections.isEmpty || showEmpty {
                    sectionDivider
                }

                if !todayManager.hasLoadedInitially {
                    loadingIndicator
                } else if showEmpty {
                    emptyContentView
                } else {
                    contentSectionsStack(sections, episodes: episodes)
                }

                TodayAttributionFooter()
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .refreshable {
            startRefreshWithoutBlocking()
        }
    }
}
