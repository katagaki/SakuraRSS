import SwiftUI

/// "Preview" section of the Web Feed builder showing matched articles.
struct PetalBuilderPreviewSection: View {

    let articles: [ParsedArticle]
    let errorMessage: String?
    let isFetching: Bool
    let hasFetchedHTML: Bool

    var body: some View {
        Section {
            contentBody
        } header: {
            header
        }
    }

    @ViewBuilder
    private var contentBody: some View {
        if let errorMessage {
            Text(errorMessage)
                .foregroundStyle(.red)
        } else if articles.isEmpty && !isFetching && hasFetchedHTML {
            Text(String(localized: "Builder.Preview.Empty", table: "Petal"))
                .foregroundStyle(.secondary)
        } else if articles.isEmpty && !hasFetchedHTML {
            Text(String(localized: "Builder.Preview.TapFetch", table: "Petal"))
                .foregroundStyle(.secondary)
        } else {
            ForEach(articles.prefix(20), id: \.url) { article in
                PetalBuilderPreviewRow(article: article)
            }
        }
    }

    private var header: some View {
        HStack {
            Text(String(localized: "Builder.Section.Preview", table: "Petal"))
            if !articles.isEmpty {
                Spacer()
                Text("\(articles.count)")
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
        }
    }
}

private struct PetalBuilderPreviewRow: View {

    let article: ParsedArticle

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(article.title)
                .font(.body)
                .lineLimit(2)
            Text(article.url)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let summary = article.summary, !summary.isEmpty {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}
