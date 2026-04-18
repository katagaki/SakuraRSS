import SwiftUI

struct CardView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.colorScheme) private var colorScheme
    let article: Article
    let onSwipedLeft: () -> Void
    let onSwipedRight: () -> Void

    @State private var offset: CGSize = .zero
    @State private var hasPassedThreshold = false
    @State private var isDismissing = false
    @State private var favicon: UIImage?
    @State private var hideImage = false
    @State private var shouldCenterImage = false

    private var rotation: Double {
        Double(offset.width) / 20.0
    }

    private var swipeProgress: Double {
        min(abs(offset.width) / 80.0, 1.0)
    }

    private var cardTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var skipLocalizationLabel: String {
        if article.isPodcastEpisode {
            return String(localized: "Cards.ListenLater", table: "Articles")
        }
        if article.isYouTubeURL {
            return String(localized: "Cards.WatchLater", table: "Articles")
        }
        return String(localized: "Cards.ReadLater", table: "Articles")
    }

    private var hasArticleImage: Bool {
        article.imageURL != nil && !hideImage
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                if hasArticleImage {
                    // Background image
                    if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                        CachedAsyncImage(url: url, alignment: shouldCenterImage ? .center : .top, onImageLoaded: { image in
                            let pixelWidth = image.size.width * image.scale
                            let pixelHeight = image.size.height * image.scale
                            if pixelWidth <= 100 && pixelHeight <= 100 {
                                hideImage = true
                            }
                        }) {
                            Rectangle()
                                .fill(.secondary.opacity(0.2))
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                    }

                    // Progressive blur over the bottom portion of the card
                    ProgressiveBlurView()
                        .frame(height: geometry.size.height * 0.5)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                } else {
                    // Favicon-based card background
                    faviconCardBackground(geometry: geometry)
                }

                // Swipe indicator overlays
                swipeIndicators

                // Title and subtitle
                VStack(alignment: .leading, spacing: 8) {
                    Spacer()

                    Text(article.title)
                        .font(.system(.title, weight: .bold))
                        .fontWidth(.condensed)
                        .foregroundStyle(cardTextColor)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)

                    if let summary = article.summary, !summary.isEmpty {
                        Text(ContentBlock.stripMarkdown(summary))
                            .font(.subheadline)
                            .foregroundStyle(cardTextColor.secondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .clipShape(.rect(cornerRadius: 24))
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            .offset(x: offset.width, y: offset.height * 0.3)
            .rotationEffect(.degrees(rotation))
            .opacity(isDismissing ? 0 : 1)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = value.translation
                        let pastThreshold = abs(value.translation.width) >= 80
                        if pastThreshold != hasPassedThreshold {
                            hasPassedThreshold = pastThreshold
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
                    .onEnded { value in
                        hasPassedThreshold = false
                        handleSwipeEnd(translation: value.translation)
                    }
            )
        }
        .task {
            if let feed = feedManager.feed(forArticle: article) {
                shouldCenterImage = CenteredImageDomains.shouldCenterImage(feedDomain: feed.domain)
                favicon = await FaviconCache.shared.favicon(for: feed)
            }
        }
    }

    @ViewBuilder
    private func faviconCardBackground(geometry: GeometryProxy) -> some View {
        let isDark = colorScheme == .dark
        let bgColor = favicon?.cardBackgroundColor(isDarkMode: isDark)
            ?? (isDark ? Color(white: 0.15) : Color(white: 0.9))

        ZStack {
            // Solid tinted background
            Rectangle()
                .fill(bgColor)

            // Favicon displayed large and slightly rotated
            if let favicon {
                Image(uiImage: favicon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width * 0.4,
                           height: geometry.size.width * 0.4)
                    .opacity(isDark ? 0.6 : 0.4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .offset(y: -geometry.size.height * 0.1)
            }

            // Bottom gradient for text readability
            LinearGradient(
                colors: [bgColor.opacity(0), bgColor],
                startPoint: .init(x: 0.5, y: 0.5),
                endPoint: .bottom
            )
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
    }

    private var swipeIndicators: some View {
        ZStack {
            // Right swipe: mark read indicator
            swipeIndicatorOverlay(
                label: String(localized: "Cards.MarkRead", table: "Articles"),
                systemImage: "envelope.open.fill",
                color: .blue,
                alignment: .topLeading,
                opacity: offset.width > 0 ? swipeProgress : 0
            )

            // Left swipe: read/watch/listen later indicator
            swipeIndicatorOverlay(
                label: skipLocalizationLabel,
                systemImage: "eye.slash.fill",
                color: .red,
                alignment: .topTrailing,
                opacity: offset.width < 0 ? swipeProgress : 0
            )
        }
    }

    private func swipeIndicatorOverlay(
        label: String,
        systemImage: String,
        color: Color,
        alignment: Alignment,
        opacity: Double
    ) -> some View {
        RoundedRectangle(cornerRadius: 24)
            .stroke(color, lineWidth: 8)
            .overlay(
                Label(label, systemImage: systemImage)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(color, in: .capsule)
                    .padding(16),
                alignment: alignment
            )
            .opacity(opacity)
    }

    private func handleSwipeEnd(translation: CGSize) {
        let threshold: CGFloat = 80
        if abs(translation.width) > threshold {
            let direction: CGFloat = translation.width > 0 ? 500 : -500
            let callback = translation.width > 0 ? onSwipedRight : onSwipedLeft
            withAnimation(.easeOut(duration: 0.3)) {
                offset = CGSize(width: direction, height: translation.height)
                isDismissing = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.smooth.speed(2.0)) {
                    callback()
                }
                offset = .zero
                isDismissing = false
            }
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                offset = .zero
            }
        }
    }
}
