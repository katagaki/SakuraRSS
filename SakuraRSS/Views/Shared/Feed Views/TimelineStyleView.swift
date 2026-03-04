import SwiftUI

struct TimelineStyleView: View {

    @Environment(FeedManager.self) var feedManager
    let articles: [Article]
    var onLoadMore: (() -> Void)?

    var body: some View {
        List {
            if let latest = articles.first {
                ZStack {
                    ArticleLink(article: latest) {
                        EmptyView()
                    }
                    .opacity(0)

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
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            let remaining = Array(articles.dropFirst())
            let groups = groupedArticles(from: remaining)

            ForEach(Array(groups.enumerated()), id: \.element.key) { _, group in
                Section {
                    ForEach(Array(group.articles.enumerated()), id: \.element.id) { index, article in
                        ZStack {
                            ArticleLink(article: article) {
                                EmptyView()
                            }
                            .opacity(0)

                            timelineRow(
                                article: article,
                                isFirst: index == 0,
                                isLast: index == group.articles.count - 1
                            )
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
            return String(localized: "Timeline.Earlier")
        }
        if calendar.isDateInToday(date) {
            return String(localized: "Timeline.Today")
        }
        if calendar.isDateInYesterday(date) {
            return String(localized: "Timeline.Yesterday")
        }
        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = false
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
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
