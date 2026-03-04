import SwiftUI

// MARK: - Environment key for zoom transition namespace

private struct CardZoomNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var cardZoomNamespace: Namespace.ID? {
        get { self[CardZoomNamespaceKey.self] }
        set { self[CardZoomNamespaceKey.self] = newValue }
    }
}

struct CardsStyleView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.cardZoomNamespace) private var zoomNamespace
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
                    ArticleLink(article: article) {
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
                    }
                    .buttonStyle(.plain)
                    .cardZoomSource(id: article.id, namespace: zoomNamespace)
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

    @Environment(\.colorScheme) private var colorScheme
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

    private var cardTextColor: Color {
        colorScheme == .dark ? .white : .black
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

                // Progressive blur over the bottom portion of the card
                ProgressiveBlurView()
                    .frame(height: geometry.size.height * 0.5)
                    .frame(maxHeight: .infinity, alignment: .bottom)

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
                        Text(summary)
                            .font(.subheadline)
                            .foregroundStyle(cardTextColor.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
                color: .blue,
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
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(color, in: .capsule),
                alignment: alignment
            )
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

// MARK: - Conditional Zoom Modifiers

extension View {
    /// Applies the zoom navigation transition only when Cards style is active,
    /// preventing strange animations in other display styles.
    @ViewBuilder
    func conditionalZoomTransition(isCards: Bool, sourceID: Int64, in namespace: Namespace.ID) -> some View {
        if isCards {
            self.navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        } else {
            self
        }
    }
}

private extension View {
    @ViewBuilder
    func cardZoomSource(id: Int64, namespace: Namespace.ID?) -> some View {
        if let namespace {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }
}

// MARK: - Progressive Blur

/// Builds a progressive blur by stacking multiple blur layers, each masked
/// to reveal only its vertical slice. The result fades from sharp at the top
/// to heavily blurred at the bottom, with a tint that adapts to the current
/// color scheme for text contrast.
private struct ProgressiveBlurView: UIViewRepresentable {

    @Environment(\.colorScheme) private var colorScheme

    private static let steps = 6

    func makeUIView(context _: Context) -> UIView {
        let container = UIView()
        container.clipsToBounds = true

        for _ in 0..<Self.steps {
            let blur = UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
            blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            container.addSubview(blur)
        }

        // Add a tint overlay for additional darkening/lightening
        let tint = UIView()
        tint.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tint.tag = 999
        container.addSubview(tint)

        return container
    }

    func updateUIView(_ container: UIView, context _: Context) {
        let blurViews = container.subviews.compactMap { $0 as? UIVisualEffectView }
        guard blurViews.count == Self.steps else { return }

        for (i, blur) in blurViews.enumerated() {
            blur.effect = UIBlurEffect(style: blurStyle)
            blur.frame = container.bounds

            let gradientMask = CAGradientLayer()
            gradientMask.frame = container.bounds
            gradientMask.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor,
                                   UIColor.black.cgColor, UIColor.black.cgColor]

            let start = CGFloat(i) / CGFloat(Self.steps)
            let end = CGFloat(i + 1) / CGFloat(Self.steps)
            gradientMask.locations = [0, NSNumber(value: start), NSNumber(value: end), 1]
            gradientMask.startPoint = CGPoint(x: 0.5, y: 0)
            gradientMask.endPoint = CGPoint(x: 0.5, y: 1)
            blur.layer.mask = gradientMask

            let fraction = CGFloat(i + 1) / CGFloat(Self.steps)
            blur.alpha = fraction
        }

        // Update tint overlay
        if let tint = container.viewWithTag(999) {
            tint.frame = container.bounds
            let tintColor: UIColor = colorScheme == .dark
                ? UIColor.black.withAlphaComponent(0.3)
                : UIColor.white.withAlphaComponent(0.3)
            tint.backgroundColor = tintColor

            let gradientMask = CAGradientLayer()
            gradientMask.frame = container.bounds
            gradientMask.colors = [UIColor.clear.cgColor, UIColor.black.cgColor]
            gradientMask.startPoint = CGPoint(x: 0.5, y: 0)
            gradientMask.endPoint = CGPoint(x: 0.5, y: 1)
            tint.layer.mask = gradientMask
        }
    }

    private var blurStyle: UIBlurEffect.Style {
        colorScheme == .dark ? .dark : .light
    }
}
