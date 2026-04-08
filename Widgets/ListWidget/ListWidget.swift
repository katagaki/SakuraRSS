import SwiftUI
import WidgetKit

// MARK: - Main Widget View

struct ListWidgetView: View {

    @Environment(\.widgetFamily) var family
    var entry: ListWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            ListWidgetSmallView(entry: entry)
                .padding(16)
        case .systemMedium:
            if entry.layout == .thumbnails {
                ListWidgetMediumThumbnailsView(entry: entry)
            } else {
                ListWidgetMediumTextView(entry: entry)
            }
        case .systemLarge:
            if entry.layout == .thumbnails {
                ListWidgetLargeThumbnailsView(entry: entry)
            } else {
                ListWidgetLargeTextView(entry: entry)
            }
        default:
            ListWidgetSmallView(entry: entry)
        }
    }
}

// MARK: - Small View

struct ListWidgetSmallView: View {

    let entry: ListWidgetEntry

    var body: some View {
        if let article = entry.articles.first {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    if let imageData = article.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .renderingMode(.original)
                            .resizable()
                            .widgetAccentedRenderingMode(.fullColor)
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color("AccentColor").opacity(0.3))
                            .overlay {
                                Image(systemName: "newspaper")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(article.title)
                        .font(.system(size: 12, weight: .semibold, design: .default).width(.condensed))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(entry.listTitle)
                        .font(.system(size: 10, weight: .medium, design: .default).width(.condensed))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
                .padding(.horizontal, 2)
            }
            .widgetURL(URL(string: "sakura://article/\(article.id)")!)
        } else {
            VStack(spacing: 4) {
                Image(systemName: "newspaper")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
                Text("Widget.NoArticles")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Title Bar

struct ListTitleBar: View {
    let title: String
    let listID: Int64
    let currentPage: Int
    let totalPages: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            if totalPages > 1 {
                HStack(spacing: 12) {
                    Button(intent: ListWidgetPageIntent(listID: listID, page: currentPage - 1)) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(currentPage > 0 ? .primary : .quaternary)
                    }
                    .disabled(currentPage <= 0)
                    .tint(.accent)

                    Text("\(currentPage + 1)/\(totalPages)")
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)

                    Button(intent: ListWidgetPageIntent(listID: listID, page: currentPage + 1)) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(currentPage < totalPages - 1 ? .primary : .quaternary)
                    }
                    .disabled(currentPage >= totalPages - 1)
                    .tint(.accent)
                }
            }
        }
    }
}

// MARK: - Medium Text View

struct ListWidgetMediumTextView: View {
    let entry: ListWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ListTitleBar(title: entry.listTitle, listID: entry.listID,
                         currentPage: entry.currentPage, totalPages: entry.totalPages)
                .padding(.horizontal, 16)
                .padding(.top, 14)

            if entry.articles.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text("Widget.NoArticles")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(entry.articles.prefix(4)) { article in
                        Link(destination: URL(string: "sakura://article/\(article.id)")!) {
                            Text(article.title)
                                .font(.system(size: 13, weight: .medium, design: .default))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 5)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.bottom, 14)
    }
}

// MARK: - Large Text View

struct ListWidgetLargeTextView: View {
    let entry: ListWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ListTitleBar(title: entry.listTitle, listID: entry.listID,
                         currentPage: entry.currentPage, totalPages: entry.totalPages)
                .padding(.horizontal, 16)
                .padding(.top, 14)

            if entry.articles.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text("Widget.NoArticles")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(entry.articles.prefix(9)) { article in
                        Link(destination: URL(string: "sakura://article/\(article.id)")!) {
                            Text(article.title)
                                .font(.system(size: 13, weight: .medium, design: .default))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 5)
                        }
                        if article.id != entry.articles.prefix(9).last?.id {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.bottom, 14)
    }
}

// MARK: - Medium Thumbnails View

struct ListWidgetMediumThumbnailsView: View {
    let entry: ListWidgetEntry

    var body: some View {
        VStack(spacing: 4) {
            ListTitleBar(title: entry.listTitle, listID: entry.listID,
                         currentPage: entry.currentPage, totalPages: entry.totalPages)
                .padding(.horizontal, 16)
                .padding(.top, 14)

            if entry.articles.isEmpty {
                Spacer()
                Text("Widget.NoArticles")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                GeometryReader { geo in
                    let cols = entry.columns
                    let spacing: CGFloat = 6
                    let totalSpacing = spacing * CGFloat(cols - 1) + 32
                    let cellWidth = (geo.size.width - totalSpacing) / CGFloat(cols)
                    let cellHeight = geo.size.height - 4

                    HStack(spacing: spacing) {
                        ForEach(entry.articles.prefix(cols)) { article in
                            Link(destination: URL(string: "sakura://article/\(article.id)")!) {
                                listThumbnailCell(article: article, width: cellWidth, height: cellHeight)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.bottom, 14)
    }
}

// MARK: - Large Thumbnails View

struct ListWidgetLargeThumbnailsView: View {
    let entry: ListWidgetEntry

    var body: some View {
        VStack(spacing: 4) {
            ListTitleBar(title: entry.listTitle, listID: entry.listID,
                         currentPage: entry.currentPage, totalPages: entry.totalPages)
                .padding(.horizontal, 16)
                .padding(.top, 14)

            if entry.articles.isEmpty {
                Spacer()
                Text("Widget.NoArticles")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                GeometryReader { geo in
                    let cols = entry.columns
                    let spacing: CGFloat = 6
                    let totalSpacing = spacing * CGFloat(cols - 1) + 32
                    let cellWidth = (geo.size.width - totalSpacing) / CGFloat(cols)
                    let rows = cols
                    let verticalSpacing: CGFloat = 6
                    let cellHeight = (geo.size.height - verticalSpacing * CGFloat(rows - 1)) / CGFloat(rows)

                    VStack(spacing: verticalSpacing) {
                        ForEach(0..<rows, id: \.self) { row in
                            HStack(spacing: spacing) {
                                ForEach(0..<cols, id: \.self) { col in
                                    let index = row * cols + col
                                    if index < entry.articles.count {
                                        let article = entry.articles[index]
                                        Link(destination: URL(string: "sakura://article/\(article.id)")!) {
                                            listThumbnailCell(article: article, width: cellWidth, height: cellHeight)
                                        }
                                    } else {
                                        Color.clear
                                            .frame(width: cellWidth, height: cellHeight)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.bottom, 14)
    }
}

// MARK: - Shared Thumbnail Cell

@ViewBuilder
private func listThumbnailCell(article: ListWidgetArticle, width: CGFloat, height: CGFloat) -> some View {
    VStack(spacing: 0) {
        if let imageData = article.imageData, let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .renderingMode(.original)
                .resizable()
                .widgetAccentedRenderingMode(.fullColor)
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height * 0.65)
                .clipped()
        } else {
            Rectangle()
                .fill(Color("AccentColor").opacity(0.15))
                .frame(width: width, height: height * 0.65)
                .overlay {
                    Image(systemName: "newspaper")
                        .font(.system(size: 16))
                        .foregroundStyle(.quaternary)
                }
        }
        Text(article.title)
            .font(.system(size: 10, weight: .medium, design: .default).width(.condensed))
            .foregroundStyle(.primary)
            .lineLimit(2)
            .frame(width: width, height: height * 0.35, alignment: .topLeading)
            .padding(.top, 3)
            .padding(.horizontal, 2)
    }
    .clipShape(RoundedRectangle(cornerRadius: 8))
}

// MARK: - Widget Definition

struct ListWidget: Widget {
    let kind = "ListWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ListWidgetIntent.self,
            provider: ListWidgetProvider()
        ) { entry in
            ListWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color("WidgetBackground")
                }
        }
        .contentMarginsDisabled()
        .configurationDisplayName(String(localized: "ListWidget.DisplayName"))
        .description(String(localized: "ListWidget.Description"))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
