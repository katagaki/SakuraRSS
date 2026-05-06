import SwiftUI

/// Horizontally paginated 4:3 carousel of headline cards.
struct SummaryHeadlineCarousel: View {

    let headlines: [SummaryHeadline]
    var horizontalPadding: CGFloat = 16
    let onSelect: (SummaryHeadline) -> Void

    @State private var visibleID: SummaryHeadline.ID?

    var body: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: horizontalPadding) {
                    ForEach(headlines) { headline in
                        Button {
                            onSelect(headline)
                        } label: {
                            SummaryHeadlineCard(headline: headline)
                                .containerRelativeFrame(.horizontal) { value, _ in
                                    max(0, value - horizontalPadding * 2)
                                }
                        }
                        .buttonStyle(.plain)
                        .id(headline.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, horizontalPadding)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $visibleID)
            .scrollClipDisabled()

            paginationDots
        }
        .onAppear {
            if visibleID == nil {
                visibleID = headlines.first?.id
            }
        }
    }

    @ViewBuilder
    private var paginationDots: some View {
        HStack(spacing: 6) {
            ForEach(headlines) { headline in
                Circle()
                    .fill(headline.id == visibleID ? Color.primary : Color.secondary.opacity(0.35))
                    .frame(width: 6, height: 6)
            }
        }
        .frame(height: 12)
        .animation(.smooth.speed(2.0), value: visibleID)
    }
}
