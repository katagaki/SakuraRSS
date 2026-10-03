import SwiftUI

/// Two-column landscape layout: a fixed glass column with the greeting,
/// weather on the leading side, and the remaining Today
/// sections scrolling beside it. Section carousels span the full width so
/// their cards flow beneath the glass column instead of clipping at its edge.
/// iPad swaps the glass for a full-height material panel beside the content.
extension TodayView {

    var isLandscapeLayout: Bool {
        verticalSizeClass == .compact || (HomeLayout.usesPadTodayLayout && isWideWindow)
    }

    var landscapeLayout: some View {
        GeometryReader { geometry in
            let columnWidth = leadingColumnWidth(for: geometry.size.width)
            if HomeLayout.usesPadTodayLayout {
                HStack(alignment: .top, spacing: 0) {
                    landscapeLeadingColumn
                        .frame(width: columnWidth)
                    landscapeTrailingScrollView(leadingContentInset: 0)
                }
            } else {
                ZStack(alignment: .topLeading) {
                    landscapeTrailingScrollView(leadingContentInset: columnWidth + 16)
                    landscapeLeadingColumn
                        .frame(width: columnWidth)
                        .padding(.leading, 16)
                        .padding(.vertical, 8)
                }
            }
        }
    }

    private func leadingColumnWidth(for availableWidth: CGFloat) -> CGFloat {
        min(380, max(280, availableWidth * 0.4))
    }

    private func landscapeTrailingScrollView(leadingContentInset: CGFloat) -> some View {
        let episodes = visibleEpisodes
        let sections = contentSections(episodes: episodes)
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !todayManager.hasLoadedInitially {
                    loadingIndicator
                } else if sections.isEmpty {
                    emptyContentView
                } else {
                    contentSectionsStack(sections, episodes: episodes)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .environment(\.todayLeadingContentInset, leadingContentInset)
        .refreshable {
            startRefreshWithoutBlocking()
        }
    }

    @ViewBuilder
    private var landscapeLeadingColumn: some View {
        if HomeLayout.usesPadTodayLayout {
            landscapeLeadingColumnContent
                .background(.ultraThinMaterial)
        } else {
            landscapeLeadingColumnContent
                // Inset the scroll indicator so it isn't clipped by the rounded corners.
                .contentMargins(.vertical, leadingColumnCornerRadius, for: .scrollIndicators)
                .compatibleGlassEffect(in: .rect(cornerRadius: leadingColumnCornerRadius))
                .clipShape(.rect(cornerRadius: leadingColumnCornerRadius))
        }
    }

    private var landscapeLeadingColumnContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TodayGreetingView(isCompact: true, isOnGlass: !HomeLayout.usesPadTodayLayout)
                    .padding(.horizontal)

                pinnedSection

                if isWeatherShowing {
                    sectionDivider
                }

                TodayAttributionFooter()
            }
            .padding(.vertical, 16)
        }
    }

    private var leadingColumnCornerRadius: CGFloat { 24 }
}
