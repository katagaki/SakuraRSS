import SwiftUI

struct CompactStyleView: View {

    @Environment(FeedManager.self) var feedManager
    let articles: [Article]

    private func articleLabel(for article: Article) -> some View {
        HStack {
            Text(article.title)
                .font(.body)
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

    var body: some View {
        List(articles) { article in
            if article.isYouTubeURL {
                Button {
                    feedManager.markRead(article)
                    YouTubeHelper.openInApp(url: article.url)
                } label: {
                    articleLabel(for: article)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSpacing(0.0)
            } else {
                NavigationLink {
                    ArticleDetailView(article: article)
                } label: {
                    articleLabel(for: article)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSpacing(0.0)
            }
        }
        .listStyle(.plain)
    }
}
