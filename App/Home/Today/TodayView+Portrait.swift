import SwiftUI

/// Single-column Today layout with content sections beneath the greeting and weather.
extension TodayView {

    var portraitLayout: some View {
        let episodes = visibleEpisodes
        let sections = contentSections(episodes: episodes)
        let showEmpty = todayManager.hasLoadedInitially && sections.isEmpty
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TodayGreetingView()
                    .padding(.horizontal)

                if let pinnedSection {
                    pinnedSection
                        .padding(.top, isWeatherShowing ? 8 : 0)
                }

                if isWeatherShowing {
                    sectionDivider
                }

                if !isWeatherShowing,
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
