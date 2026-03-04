import SwiftUI

struct TimelineStyleView: View {

    @Environment(FeedManager.self) var feedManager
    let articles: [Article]
    var onLoadMore: (() -> Void)?

    var body: some View {
        List {
            if let latest = articles.first {
                ArticleLink(article: latest) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let date = latest.publishedDate {
                            RelativeTimeText(date: date)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text(latest.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(latest.isRead ? .secondary : .primary)
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            let timelineArticles = Array(articles.dropFirst())
            ForEach(Array(timelineArticles.enumerated()), id: \.element.id) { index, article in
                ArticleLink(article: article) {
                    timelineRow(
                        article: article,
                        isFirst: index == 0,
                        isLast: index == timelineArticles.count - 1
                    )
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowSpacing(0)
            }

            if let onLoadMore {
                LoadPreviousArticlesButton(action: onLoadMore)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }

    private func timelineRow(article: Article, isFirst: Bool, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Group {
                if let date = article.publishedDate {
                    RelativeTimeText(date: date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("")
                        .font(.caption)
                }
            }
            .frame(width: 64, alignment: .trailing)
            .padding(.top, 12)

            TimelineConnector(isFirst: isFirst, isLast: isLast, isRead: article.isRead)
                .frame(width: 28)

            Text(article.title)
                .font(.subheadline)
                .fontWeight(article.isRead ? .regular : .medium)
                .foregroundStyle(article.isRead ? .secondary : .primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
        }
    }
}

private struct TimelineConnector: View {

    let isFirst: Bool
    let isLast: Bool
    let isRead: Bool

    var body: some View {
        GeometryReader { geometry in
            let midX = geometry.size.width / 2
            let dotSize: CGFloat = 10
            let dotY: CGFloat = 19

            if !isFirst {
                Path { path in
                    path.move(to: CGPoint(x: midX, y: 0))
                    path.addLine(to: CGPoint(x: midX, y: dotY - dotSize / 2))
                }
                .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
            }

            if !isLast {
                Path { path in
                    path.move(to: CGPoint(x: midX, y: dotY + dotSize / 2))
                    path.addLine(to: CGPoint(x: midX, y: geometry.size.height))
                }
                .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
            }

            Circle()
                .fill(isRead ? Color.secondary.opacity(0.4) : Color.accentColor)
                .frame(width: dotSize, height: dotSize)
                .position(x: midX, y: dotY)
        }
    }
}
