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
                        isTopCard: index == 0,
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
    let isTopCard: Bool
    let onSwipedLeft: () -> Void
    let onSwipedRight: () -> Void

    @State private var offset: CGSize = .zero
    @State private var isDragging = false

    private var rotation: Double {
        Double(offset.width) / 20.0
    }

    private var swipeProgress: Double {
        min(abs(offset.width) / 150.0, 1.0)
    }

    var body: some View {
        GeometryReader { geometry in
            let cardWidth = geometry.size.width
            let cardHeight = geometry.size.height

            ZStack(alignment: .bottomLeading) {
                // Background image
                if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                    CachedAsyncImage(url: url) {
                        Rectangle()
                            .fill(.secondary.opacity(0.2))
                    }
                    .frame(width: cardWidth, height: cardHeight)
                    .clipped()
                }

                // Gradient overlay for text readability
                LinearGradient(
                    colors: [.clear, .clear, .black.opacity(0.7), .black.opacity(0.9)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Swipe indicator overlays
                ZStack {
                    // Right swipe: mark read indicator
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.green, lineWidth: 4)
                        .overlay(
                            Label(String(localized: "Cards.MarkRead"), systemImage: "checkmark.circle.fill")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.green)
                                .padding(12)
                                .background(.ultraThinMaterial, in: .capsule),
                            alignment: .topLeading
                        )
                        .padding(8)
                        .opacity(offset.width > 0 ? swipeProgress : 0)

                    // Left swipe: skip indicator
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.red, lineWidth: 4)
                        .overlay(
                            Label(String(localized: "Cards.Skip"), systemImage: "xmark.circle.fill")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.red)
                                .padding(12)
                                .background(.ultraThinMaterial, in: .capsule),
                            alignment: .topTrailing
                        )
                        .padding(8)
                        .opacity(offset.width < 0 ? swipeProgress : 0)
                }

                // Title and subtitle
                VStack(alignment: .leading, spacing: 8) {
                    Text(article.title)
                        .font(.system(.title, weight: .bold, width: .condensed))
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
                        isDragging = true
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 150
                        if value.translation.width > threshold {
                            withAnimation(.easeOut(duration: 0.3)) {
                                offset = CGSize(width: 500, height: value.translation.height)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onSwipedRight()
                                offset = .zero
                            }
                        } else if value.translation.width < -threshold {
                            withAnimation(.easeOut(duration: 0.3)) {
                                offset = CGSize(width: -500, height: value.translation.height)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onSwipedLeft()
                                offset = .zero
                            }
                        } else {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                offset = .zero
                            }
                        }
                        isDragging = false
                    }
            )
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isDragging)
        }
    }
}
