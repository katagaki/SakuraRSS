import SwiftUI
import Hanami

struct BookmarkPreviewSection: View {

    @Environment(FeedManager.self) private var feedManager

    let article: Article

    @State private var isRefreshing = false

    private var currentArticle: Article {
        feedManager.article(byID: article.id) ?? article
    }

    var body: some View {
        Section {
            HStack(spacing: 14) {
                previewImage
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentArticle.imageURL == nil
                         ? String(localized: "BookmarkDetail.Preview.None", table: "Articles")
                         : String(localized: "BookmarkDetail.Preview.Found", table: "Articles"))
                        .font(.subheadline)
                    Text(article.url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Button {
                Task { await refresh() }
            } label: {
                HStack {
                    Label(String(localized: "BookmarkDetail.Preview.Refresh", table: "Articles"),
                          systemImage: "photo.badge.arrow.down")
                    if isRefreshing {
                        Spacer()
                        ProgressView().controlSize(.small)
                    }
                }
            }
            .disabled(isRefreshing)
        } header: {
            Text(String(localized: "BookmarkDetail.Preview.Header", table: "Articles"))
        } footer: {
            Text(String(localized: "BookmarkDetail.Preview.Footer", table: "Articles"))
        }
    }

    @ViewBuilder
    private var previewImage: some View {
        if let imageURL = currentArticle.imageURL, let url = URL(string: imageURL) {
            CachedAsyncImage(url: url, maxPixelSize: 160) {
                Color.secondary.opacity(0.2)
            }
            .frame(width: 64, height: 64)
            .clipShape(.rect(cornerRadius: 8))
        } else {
            BookmarkSiteIcon(article: article, size: 64, cornerRadius: 8)
        }
    }

    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        let articleID = article.id
        let url = article.url
        await BookmarkPreviewResolver.refreshPreview(forArticleID: articleID, url: url)
        feedManager.bumpDataRevision()
    }
}
