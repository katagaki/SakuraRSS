import SwiftUI

/// Horizontally scrolling card carousel matching the Insights / Discover
/// layout, used by all Today section rows. The card builder is generic so
/// the same layout can host 16:9 article cards or square podcast cards.
struct TodayCardCarousel<Card: View>: View {

    let title: String
    let destination: EntityDestination?
    let articles: [Article]
    @ViewBuilder let card: (Article) -> Card

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(articles) { article in
                        card(article)
                            .contextMenu {
                                TodayCardContextMenu(article: article)
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        if let destination {
            NavigationLink(value: destination) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        } else {
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
        }
    }
}

extension TodayCardCarousel where Card == DiscoverArticleCard {
    init(title: String, destination: EntityDestination?, articles: [Article]) {
        self.init(title: title, destination: destination, articles: articles) { article in
            DiscoverArticleCard(article: article)
        }
    }
}
