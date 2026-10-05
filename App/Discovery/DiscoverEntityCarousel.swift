import SwiftUI
import Hanami

/// One topic or person, with the content that mentions it.
struct DiscoverEntityCarousel: View {

    let section: DiscoverEntitySection

    var body: some View {
        if !section.articles.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                NavigationLink(value: EntityDestination(name: section.name, types: section.types)) {
                    HStack(spacing: 4) {
                        Text(section.name)
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
                .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(section.articles) { article in
                            DiscoverArticleCard(article: article)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}
