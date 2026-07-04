import SwiftUI

/// Two-column landscape layout: a fixed glass column with the greeting,
/// weather, and headlines on the leading side, and the remaining Today
/// sections scrolling beside it. Section carousels span the full width so
/// their cards flow beneath the glass column instead of clipping at its edge.
extension TodayView {

    var isLandscapeLayout: Bool {
        verticalSizeClass == .compact
    }

    var landscapeLayout: some View {
        GeometryReader { geometry in
            let columnWidth = leadingColumnWidth(for: geometry.size.width)
            ZStack(alignment: .topLeading) {
                landscapeTrailingScrollView(columnWidth: columnWidth)
                landscapeLeadingColumn
                    .frame(width: columnWidth)
                    .padding(.leading, 16)
                    .padding(.vertical, 8)
            }
        }
    }

    private func leadingColumnWidth(for availableWidth: CGFloat) -> CGFloat {
        min(380, max(280, availableWidth * 0.4))
    }

    private func landscapeTrailingScrollView(columnWidth: CGFloat) -> some View {
        let sections = contentSections
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !todayManager.hasLoadedInitially {
                    loadingIndicator
                } else if sections.isEmpty {
                    emptyContentView
                } else {
                    contentSectionsStack(sections)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .environment(\.todayLeadingContentInset, columnWidth + 16)
        .refreshable {
            startRefreshWithoutBlocking()
        }
    }

    private var landscapeLeadingColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TodayGreetingView(isCompact: true)
                    .padding(.horizontal)

                if isWeatherShowing || anySummaryActive {
                    sectionDivider
                }

                if anySummaryActive {
                    summaryCardsStack
                }

                TodayAttributionFooter()
            }
            .padding(.vertical, 16)
        }
        // Inset the scroll indicator so it isn't clipped by the rounded corners.
        .contentMargins(.vertical, leadingColumnCornerRadius, for: .scrollIndicators)
        .compatibleGlassEffect(in: .rect(cornerRadius: leadingColumnCornerRadius))
        .clipShape(.rect(cornerRadius: leadingColumnCornerRadius))
    }

    private var leadingColumnCornerRadius: CGFloat { 24 }
}
