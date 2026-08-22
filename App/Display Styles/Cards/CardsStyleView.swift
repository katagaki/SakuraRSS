import SwiftUI
import Hanami

struct CardsStyleView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.zoomNamespace) private var zoomNamespace
    let articles: [Article]
    var onRefresh: (() async -> Void)?

    /// Snapshot of unread article IDs; prevents cards vanishing during markRead navigation.
    @State private var deckArticleIDs: Set<Int64>?
    @State private var selectedArticle: Article?

    /// Session-scoped swipe dismissals; resets on navigate-away-and-back.
    @State private var dismissedIDs: Set<Int64> = []

    /// Only the top two cards are ever rendered, so the scan stops there.
    private var visibleCards: [Article] {
        guard let deckArticleIDs else { return [] }
        var cards: [Article] = []
        for article in articles {
            guard deckArticleIDs.contains(article.id),
                  !dismissedIDs.contains(article.id) else { continue }
            cards.append(article)
            if cards.count == 2 { break }
        }
        return cards
    }

    @State private var isRefreshing = false

    private var hasUnreadCards: Bool {
        articles.contains { !$0.isRead }
    }

    var body: some View {
        let cards = visibleCards
        return ZStack {
            if cards.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "Cards.Empty.Title", table: "Articles"),
                          systemImage: "rectangle.stack")
                } description: {
                    Text(String(localized: "Cards.Empty.Description", table: "Articles"))
                } actions: {
                    if hasUnreadCards {
                        Button {
                            Task {
                                isRefreshing = true
                                await onRefresh?()
                                withAnimation(.smooth.speed(2.0)) {
                                    dismissedIDs.removeAll()
                                    deckArticleIDs = Set(
                                        articles.filter { !$0.isRead }.map(\.id)
                                    )
                                }
                                isRefreshing = false
                            }
                        } label: {
                            Label(
                                String(localized: "Cards.StartOver", table: "Articles"),
                                systemImage: "arrow.counterclockwise"
                            )
                        }
                        .buttonStyle(.bordered)
                        .disabled(isRefreshing)
                    }
                }
            } else {
                ForEach(Array(cards.enumerated().reversed()),
                        id: \.element.id) { index, article in
                    ArticleLink(article: article, onNavigate: {
                        selectedArticle = $0
                    }, marksRead: false, label: {
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
                    })
                    .buttonStyle(.plain)
                    .scaleEffect(1.0 - CGFloat(index) * 0.04)
                    .offset(y: CGFloat(index) * 8)
                    .allowsHitTesting(index == 0)
                    .transition(.asymmetric(insertion: .opacity, removal: .identity))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationDestination(item: $selectedArticle) { article in
            let raw = feedManager.article(byID: article.id) ?? article
            ArticleDetailView(article: raw, marksReadOnAppear: false)
                .zoomTransition(sourceID: article.id, in: zoomNamespace)
        }
        .onAppear {
            if deckArticleIDs == nil {
                deckArticleIDs = Set(
                    articles.filter { !$0.isRead }.map(\.id)
                )
            }
        }
    }
}
