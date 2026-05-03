import SwiftUI

/// Horizontally scrolling card carousel matching the Insights / Discover
/// layout, used by all Today section rows.
struct TodayCardCarousel: View {

    let title: String
    let destination: EntityDestination?
    let articles: [Article]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(articles) { article in
                        DiscoverArticleCard(article: article)
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
