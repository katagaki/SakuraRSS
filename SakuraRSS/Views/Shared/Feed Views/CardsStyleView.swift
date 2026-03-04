import SwiftUI

struct CardsStyleView: View {

    @Environment(FeedManager.self) var feedManager
    let articles: [Article]

    /// Articles with images only, filtered to unread for the current session deck.
    private var deckArticles: [Article] {
        articles.filter { $0.imageURL != nil && !$0.isRead }
    }

    /// Tracks article IDs that have been swiped away during this view's lifetime.
    /// This keeps the deck session-scoped: navigating away and back resets the deck.
    @State private var dismissedIDs: Set<Int64> = []

    private var visibleCards: [Article] {
        deckArticles.filter { !dismissedIDs.contains($0.id) }
    }

    var body: some View {
        ZStack {
            if visibleCards.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "Cards.Empty.Title"),
                          systemImage: "rectangle.stack")
                } description: {
                    Text("Cards.Empty.Description")
                }
            } else {
                // Show top 3 cards for depth effect, bottom cards drawn first
                ForEach(Array(visibleCards.prefix(3).enumerated().reversed()),
                        id: \.element.id) { index, article in
                    CardView(
                        article: article,
                        onSwipedLeft: {
                            dismissedIDs.insert(article.id)
                        },
                        onSwipedRight: {
                            feedManager.markRead(article)
                            dismissedIDs.insert(article.id)
                        }
                    )
                    .scaleEffect(1.0 - CGFloat(index) * 0.04)
                    .offset(y: CGFloat(index) * 8)
                    .allowsHitTesting(index == 0)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Individual Card

private struct CardView: View {

    let article: Article
    let onSwipedLeft: () -> Void
    let onSwipedRight: () -> Void

    @State private var offset: CGSize = .zero

    private var rotation: Double {
        Double(offset.width) / 20.0
    }

    private var swipeProgress: Double {
        min(abs(offset.width) / 150.0, 1.0)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                // Background image
                if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                    CachedAsyncImage(url: url) {
                        Rectangle()
                            .fill(.secondary.opacity(0.2))
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                }

                // Gradient overlay for text readability
                LinearGradient(
                    colors: [.clear, .clear, .black.opacity(0.7), .black.opacity(0.9)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Swipe indicator overlays
                swipeIndicators

                // Title and subtitle
                VStack(alignment: .leading, spacing: 8) {
                    Text(article.title)
                        .font(.system(.title, weight: .bold))
                        .fontWidth(.condensed)
                        .foregroundStyle(.white)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)

                    if let summary = article.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.subheadline)
                            .foregroundStyle(.white.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(24)
                .padding(.bottom, 8)
            }
            .clipShape(.rect(cornerRadius: 24))
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            .offset(x: offset.width, y: offset.height * 0.3)
            .rotationEffect(.degrees(rotation))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = value.translation
                    }
                    .onEnded { value in
                        handleSwipeEnd(translation: value.translation)
                    }
            )
        }
    }

    private var swipeIndicators: some View {
        ZStack {
            // Right swipe: mark read indicator
            swipeIndicatorOverlay(
                localizationKey: "Cards.MarkRead",
                systemImage: "checkmark.circle.fill",
                color: .green,
                alignment: .topLeading,
                opacity: offset.width > 0 ? swipeProgress : 0
            )

            // Left swipe: skip indicator
            swipeIndicatorOverlay(
                localizationKey: "Cards.Skip",
                systemImage: "xmark.circle.fill",
                color: .red,
                alignment: .topTrailing,
                opacity: offset.width < 0 ? swipeProgress : 0
            )
        }
    }

    private func swipeIndicatorOverlay(
        localizationKey: String.LocalizationValue,
        systemImage: String,
        color: Color,
        alignment: Alignment,
        opacity: Double
    ) -> some View {
        RoundedRectangle(cornerRadius: 24)
            .stroke(color, lineWidth: 4)
            .overlay(
                Label(String(localized: localizationKey), systemImage: systemImage)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(color)
                    .padding(12)
                    .background(.ultraThinMaterial, in: .capsule),
                alignment: alignment
            )
            .padding(8)
            .opacity(opacity)
    }

    private func handleSwipeEnd(translation: CGSize) {
        let threshold: CGFloat = 150
        if abs(translation.width) > threshold {
            let direction: CGFloat = translation.width > 0 ? 500 : -500
            let callback = translation.width > 0 ? onSwipedRight : onSwipedLeft
            withAnimation(.easeOut(duration: 0.3)) {
                offset = CGSize(width: direction, height: translation.height)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                callback()
                offset = .zero
            }
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                offset = .zero
            }
        }
    }
}
