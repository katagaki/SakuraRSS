import SwiftUI
import Hanami

struct TimelineStyleView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.zoomNamespace) private var zoomNamespace
    #if targetEnvironment(macCatalyst)
    @Environment(\.openWindow) private var openWindow
    #endif
    let articles: [Article]
    var onLoadMore: (() -> Void)?
    var headerView: AnyView?
    var usesStackLayout: Bool = false
    // Computed in init: body re-evaluates on every read-mask flush via
    // isRead, and regrouping the whole list there costs a Calendar/ICU
    // call per article.
    private let groups: [(key: String, articles: [Article])]

    init(
        articles: [Article],
        onLoadMore: (() -> Void)? = nil,
        headerView: AnyView? = nil,
        usesStackLayout: Bool = false
    ) {
        self.articles = articles
        self.onLoadMore = onLoadMore
        self.headerView = headerView
        self.usesStackLayout = usesStackLayout
        self.groups = Self.groupedArticles(from: articles)
    }

    var body: some View {
        if usesStackLayout {
            stackLayout
        } else {
            listLayout
        }
    }

    private var listLayout: some View {
        List {
            if let headerView {
                headerView
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
            }
            ForEach(Array(groups.enumerated()), id: \.element.key) { groupIndex, group in
                Section {
                    ForEach(Array(group.articles.enumerated()), id: \.element.id) { index, article in
                        ZStack {
                            ArticleLink(article: article, label: {
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
                            .markReadOnScroll(article: article)
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowSpacing(0)
                        .contextMenu {
                            rowContextMenu(for: article)
                        }
                    }
                } header: {
                    sectionHeader(group.key)
                }
            }

            if let onLoadMore {
                LoadPreviousArticlesButton(action: onLoadMore, articleCount: articles.count)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(.compact)
        .environment(\.defaultMinListHeaderHeight, 0)
        .trackScrollActivity()
    }

    private var stackLayout: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                if let headerView {
                    headerView
                }
                ForEach(Array(groups.enumerated()), id: \.element.key) { groupIndex, group in
                    sectionHeader(group.key)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, groupIndex == 0 ? 4 : 12)
                        .padding(.bottom, 4)
                    ForEach(Array(group.articles.enumerated()), id: \.element.id) { index, article in
                        ArticleLink(article: article, label: {
                            timelineRow(
                                article: article,
                                isFirst: index == 0,
                                isLast: index == group.articles.count - 1,
                                isFeatured: groupIndex == 0 && index == 0
                            )
                            .zoomSource(id: article.id, namespace: zoomNamespace)
                            .markReadOnScroll(article: article)
                            .contentShape(.rect)
                        })
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .contextMenu {
                            rowContextMenu(for: article)
                        }
                        // Lazy containers reuse the context menu interaction, which can
                        // present the previously long-pressed item's menu without an
                        // explicit identity.
                        .id(article.id)
                    }
                }

                if let onLoadMore {
                    LoadPreviousArticlesButton(action: onLoadMore, articleCount: articles.count)
                }
            }
        }
        .trackScrollActivity()
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(nil)
    }

    @ViewBuilder
    private func rowContextMenu(for article: Article) -> some View {
        #if targetEnvironment(macCatalyst)
        OpenInNewWindowButton(article: article)
        Divider()
        Button {
            feedManager.toggleRead(article)
        } label: {
            Label(
                feedManager.isRead(article)
                    ? String(localized: "Article.MarkUnread", table: "Articles")
                    : String(localized: "Article.MarkRead", table: "Articles"),
                systemImage: feedManager.isRead(article) ? "envelope" : "envelope.open"
            )
        }
        #endif
        MoveToFolderMenuItems(article: article)
    }

    private static func groupedArticles(from articles: [Article]) -> [(key: String, articles: [Article])] {
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

    private static func daySectionTitle(for date: Date?, calendar: Calendar) -> String {
        guard let date else {
            return String(localized: "Timeline.Earlier", table: "Articles")
        }
        if calendar.isDateInToday(date) {
            return String(localized: "Timeline.Today", table: "Articles")
        }
        if calendar.isDateInYesterday(date) {
            return String(localized: "Timeline.Yesterday", table: "Articles")
        }
        return Self.daySectionFormatter.string(from: date)
    }

    private static let daySectionFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = false
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

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

            TimelineConnector(isFirst: isFirst, isLast: isLast, isRead: feedManager.isRead(article))
                .frame(width: 28)

            Text(article.title)
                .font(isFeatured ? .body : .subheadline)
                .fontWeight(titleWeight(isFeatured: isFeatured, isRead: feedManager.isRead(article)))
                .foregroundStyle(feedManager.isRead(article) ? .secondary : .primary)
                .lineLimit(isFeatured ? 3 : 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
        }
    }
}
