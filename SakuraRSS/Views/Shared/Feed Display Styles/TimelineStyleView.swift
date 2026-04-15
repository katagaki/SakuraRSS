import SwiftUI

struct TimelineStyleView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.zoomNamespace) private var zoomNamespace
    let articles: [Article]
    var onLoadMore: (() -> Void)?
    @State private var youTubeArticle: Article?

    var body: some View {
        List {
            let groups = groupedArticles(from: articles)

            ForEach(Array(groups.enumerated()), id: \.element.key) { groupIndex, group in
                Section {
                    ForEach(Array(group.articles.enumerated()), id: \.element.id) { index, article in
                        ZStack {
                            ArticleLink(article: article, onShowYouTubePlayer: {
                                youTubeArticle = $0
                            }, label: {
                                EmptyView()
                            })
                            .opacity(0)

                            timelineRow(
                                article: article,
                                isFirst: index == 0,
                                isLast: index == group.articles.count - 1,
                                isFeatured: groupIndex == 0 && index == 0
                            )
                            .zoomSource(id: article.id, namespace: zoomNamespace)
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowSpacing(0)
                    }
                } header: {
                    Text(group.key)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }

            if let onLoadMore {
                LoadPreviousArticlesButton(action: onLoadMore)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .navigationDestination(item: $youTubeArticle) { article in
            YouTubePlayerView(article: article)
                .zoomTransition(sourceID: article.id, in: zoomNamespace)
        }
    }

    private func groupedArticles(from articles: [Article]) -> [(key: String, articles: [Article])] {
        let calendar = Calendar.current
        var groups: [(key: String, articles: [Article])] = []
        var currentKey: String?
        var currentArticles: [Article] = []

        for article in articles {
            let key = daySectionTitle(for: article.publishedDate, calendar: calendar)
            if key == currentKey {
                currentArticles.append(article)
            } else {
                if let currentKey, !currentArticles.isEmpty {
                    groups.append((key: currentKey, articles: currentArticles))
                }
                currentKey = key
                currentArticles = [article]
            }
        }
        if let currentKey, !currentArticles.isEmpty {
            groups.append((key: currentKey, articles: currentArticles))
        }
        return groups
    }

    private func daySectionTitle(for date: Date?, calendar: Calendar) -> String {
        guard let date else {
            return String(localized: "Timeline.Earlier", table: "Articles")
        }
        if calendar.isDateInToday(date) {
            return String(localized: "Timeline.Today", table: "Articles")
        }
        if calendar.isDateInYesterday(date) {
            return String(localized: "Timeline.Yesterday", table: "Articles")
        }
        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = false
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func titleWeight(isFeatured: Bool, isRead: Bool) -> Font.Weight {
        if isFeatured { return .semibold }
        return isRead ? .regular : .medium
    }

    private func timelineRow(article: Article, isFirst: Bool, isLast: Bool,
                             isFeatured: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Group {
                if let date = article.publishedDate {
                    RelativeTimeText(date: date)
                        .font(isFeatured ? .subheadline : .caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("")
                        .font(isFeatured ? .subheadline : .caption)
                }
            }
            .frame(width: 64, alignment: .trailing)
            .padding(.top, 12)

            TimelineConnector(isFirst: isFirst, isLast: isLast, isRead: article.isRead)
                .frame(width: 28)

            Text(article.title)
                .font(isFeatured ? .body : .subheadline)
                .fontWeight(titleWeight(isFeatured: isFeatured, isRead: article.isRead))
                .foregroundStyle(article.isRead ? .secondary : .primary)
                .lineLimit(isFeatured ? 3 : 2)
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
                .fill(isRead ? Color.blue.opacity(0.3) : Color.blue)
                .frame(width: dotSize, height: dotSize)
                .position(x: midX, y: dotY)
        }
    }
}
