import Hanami
import SwiftUI

struct TodayCardRow: View {

    let title: String
    let articles: [Article]
    let feedManager: FeedManager
    let actions: TodayActions
    var usesSquareCards = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal, 24)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(articles) { article in
                        Button {
                            actions.open(.article(article.id))
                        } label: {
                            TodayCard(
                                article: article,
                                feedTitle: feedManager.feedsByID[article.feedID]?.title,
                                isSquare: usesSquareCards
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            TodayOpenInNewTabButton(location: .article(article.id), actions: actions)
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.never)
        }
    }
}
