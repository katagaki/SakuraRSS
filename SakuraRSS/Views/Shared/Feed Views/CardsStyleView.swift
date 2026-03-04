import SwiftUI

// MARK: - Environment key for zoom transition namespace

private struct ZoomNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var zoomNamespace: Namespace.ID? {
        get { self[ZoomNamespaceKey.self] }
        set { self[ZoomNamespaceKey.self] = newValue }
    }
}

struct CardsStyleView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.zoomNamespace) private var zoomNamespace
    let articles: [Article]

    /// Snapshot of article IDs that were unread when the deck was built.
    /// Using a snapshot prevents cards from disappearing when markRead is
    /// called during navigation, which would remove the matched transition
    /// source and break the zoom animation.
    @State private var deckArticleIDs: Set<Int64>?

    private var deckArticles: [Article] {
        guard let ids = deckArticleIDs else { return [] }
        return articles.filter { ids.contains($0.id) && $0.imageURL != nil }
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
                        .zoomSource(id: article.id, namespace: zoomNamespace)
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(1.0 - CGFloat(index) * 0.04)
                    .offset(y: CGFloat(index) * 8)
                    .allowsHitTesting(index == 0)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if deckArticleIDs == nil {
                deckArticleIDs = Set(
                    articles.filter { $0.imageURL != nil && !$0.isRead }.map(\.id)
                )
            }
        }
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
                systemImage: "envelope.open.fill",
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
            .stroke(color, lineWidth: 8)
            .overlay(
                Label(String(localized: localizationKey), systemImage: systemImage)
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

// MARK: - Zoom Modifiers

extension View {
    /// Applies the zoom navigation transition on the destination side.
    /// When no matching `matchedTransitionSource` exists, the system
    /// falls back to the default push transition automatically.
    func zoomTransition(sourceID: Int64, in namespace: Namespace.ID) -> some View {
        self.navigationTransition(.zoom(sourceID: sourceID, in: namespace))
    }

    /// Marks this view as the source for a zoom navigation transition.
    @ViewBuilder
    func zoomSource(id: Int64, namespace: Namespace.ID?) -> some View {
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
///
/// Uses a custom UIView subclass so that gradient masks are re-applied in
/// `layoutSubviews`, ensuring the blur is visible on the very first display
/// (not just after the view reappears).
private struct ProgressiveBlurView: UIViewRepresentable {

    @Environment(\.colorScheme) private var colorScheme

    func makeUIView(context _: Context) -> ProgressiveBlurUIView {
        ProgressiveBlurUIView(blurStyle: blurStyle)
    }

    func updateUIView(_ view: ProgressiveBlurUIView, context _: Context) {
        view.update(blurStyle: blurStyle)
    }

    private var blurStyle: UIBlurEffect.Style {
        colorScheme == .dark ? .dark : .light
    }
}

private final class ProgressiveBlurUIView: UIView {

    static let steps = 6
    private var blurStyle: UIBlurEffect.Style
    private let tintOverlay = UIView()

    init(blurStyle: UIBlurEffect.Style) {
        self.blurStyle = blurStyle
        super.init(frame: .zero)
        clipsToBounds = true

        for _ in 0..<Self.steps {
            let blur = UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
            blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(blur)
        }

        tintOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(tintOverlay)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError() }

    func update(blurStyle style: UIBlurEffect.Style) {
        blurStyle = style
        for case let blur as UIVisualEffectView in subviews {
            blur.effect = UIBlurEffect(style: style)
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let blurViews = subviews.compactMap { $0 as? UIVisualEffectView }
        guard blurViews.count == Self.steps else { return }

        for (index, blur) in blurViews.enumerated() {
            blur.frame = bounds

            let mask = CAGradientLayer()
            mask.frame = bounds
            mask.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor,
                           UIColor.black.cgColor, UIColor.black.cgColor]

            let start = CGFloat(index) / CGFloat(Self.steps)
            let end = CGFloat(index + 1) / CGFloat(Self.steps)
            mask.locations = [0, NSNumber(value: start), NSNumber(value: end), 1]
            mask.startPoint = CGPoint(x: 0.5, y: 0)
            mask.endPoint = CGPoint(x: 0.5, y: 1)
            blur.layer.mask = mask

            blur.alpha = CGFloat(index + 1) / CGFloat(Self.steps)
        }

        // Tint overlay
        tintOverlay.frame = bounds
        tintOverlay.backgroundColor = blurStyle == .dark
            ? UIColor.black.withAlphaComponent(0.3)
            : UIColor.white.withAlphaComponent(0.3)

        let tintMask = CAGradientLayer()
        tintMask.frame = bounds
        tintMask.colors = [UIColor.clear.cgColor, UIColor.black.cgColor]
        tintMask.startPoint = CGPoint(x: 0.5, y: 0)
        tintMask.endPoint = CGPoint(x: 0.5, y: 1)
        tintOverlay.layer.mask = tintMask
    }
}
