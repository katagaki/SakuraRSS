import SwiftUI

struct SummaryHeadlineCard: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.zoomNamespace) private var zoomNamespace
    @Environment(\.colorScheme) private var colorScheme
    let headline: SummaryHeadline

    @State private var primaryFeedIcon: UIImage?
    @State private var primaryFeedIsSocial = false

    private var primaryFeed: Feed? {
        guard let feedID = headline.feedIDs.first else { return nil }
        return feedManager.feedsByID[feedID]
    }

    /// Stable Int64 ID for the zoom transition. We can't use the headline's
    /// UUID directly (the matched-transition API takes Int64), so derive it
    /// from the first article ID, which is stable across reloads from cache.
    var zoomTransitionID: Int64 {
        headline.articleIDs.first ?? 0
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            thumbnail
            BottomBlurOverlay()
            BottomDarkGradient()
            VStack(alignment: .leading, spacing: 12) {
                Spacer()
                Text(headline.headline)
                    .font(.system(.title2, weight: .bold))
                    .fontWidth(.condensed)
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)

            SummaryFeedIconStack(feedIDs: headline.feedIDs)
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
        .zoomSource(id: zoomTransitionID, namespace: zoomNamespace)
        .task {
            guard let feed = primaryFeed else { return }
            primaryFeedIsSocial = feed.isSocialFeed
            primaryFeedIcon = await IconCache.shared.icon(for: feed)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let urlString = headline.thumbnailURL, let url = URL(string: urlString) {
            CachedAsyncImage(url: url, alignment: .center) {
                feedIconBackground
            }
        } else {
            feedIconBackground
        }
    }

    @ViewBuilder
    private var feedIconBackground: some View {
        FeedIconPlaceholder(
            icon: primaryFeedIcon,
            acronymIcon: primaryFeed?.acronymIcon.flatMap { UIImage(data: $0) },
            feedName: primaryFeed?.title,
            isSocialFeed: primaryFeedIsSocial,
            iconSize: 80,
            fallback: .symbol("doc.text")
        )
    }
}

private struct BottomBlurOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            ProgressiveBlurView()
                .frame(height: geometry.size.height * 0.55)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
}

private struct BottomDarkGradient: View {
    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [
                    Color.black.opacity(0),
                    Color.black.opacity(0.25)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: geometry.size.height * 0.6)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .allowsHitTesting(false)
        }
    }
}
