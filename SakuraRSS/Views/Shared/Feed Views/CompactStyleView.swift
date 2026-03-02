import SwiftUI

struct CompactStyleView: View {

    @Environment(FeedManager.self) var feedManager
    let articles: [Article]

    var body: some View {
        List(articles) { article in
            NavigationLink {
                ArticleDetailView(article: article)
            } label: {
                HStack {
                    Text(article.title)
                        .font(.caption)
                        .fontWeight(article.isRead ? .regular : .medium)
                        .foregroundStyle(article.isRead ? .secondary : .primary)
                        .lineLimit(1)

                    Spacer()

                    if let date = article.publishedDate {
                        Text(date, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .listRowSpacing(0.0)


        }
        .listStyle(.plain)
    }
}
