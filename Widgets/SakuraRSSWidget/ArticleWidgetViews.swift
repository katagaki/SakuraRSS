import SwiftUI
import WidgetKit

struct ArticleWidgetView: View {

    @Environment(\.widgetFamily) var family
    var entry: ArticleProvider.Entry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            MediumWidgetView(entry: entry)
        }
    }
}

struct MediumWidgetView: View {

    let entry: ArticleEntry

    var body: some View {
        if entry.articles.isEmpty {
            VStack(spacing: 4) {
                Image(systemName: "newspaper")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
                Text("Widget.NoArticles")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(entry.articles.prefix(4)) { article in
                    Link(destination: URL(string: "sakura://article/\(article.id)")!) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(article.title)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            Text(article.feedName)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if article.id != entry.articles.prefix(4).last?.id {
                        Divider()
                    }
                }
            }
        }
    }
}

struct LargeWidgetView: View {

    let entry: ArticleEntry

    var body: some View {
        if entry.articles.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "newspaper")
                    .font(.system(size: 34))
                    .foregroundStyle(.secondary)
                Text("Widget.NoArticles")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(entry.articles.prefix(9)) { article in
                    Link(destination: URL(string: "sakura://article/\(article.id)")!) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(article.title)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(2)

                            Text(article.feedName)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if article.id != entry.articles.prefix(9).last?.id {
                        Divider()
                    }
                }
            }
        }
    }
}
