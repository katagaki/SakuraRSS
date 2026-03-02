import SwiftUI
@preconcurrency import Translation

struct ArticleDetailView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.openURL) var openURL
    let article: Article
    @State private var favicon: UIImage?
    @State private var extractedText: String?
    @State private var isExtracting = false
    @State private var translatedText: String?
    @State private var translationConfig: TranslationSession.Configuration?

    var displayText: String? {
        translatedText ?? extractedText ?? article.summary
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(article.title)
                    .font(.title2)
                    .fontWeight(.bold)

                HStack(spacing: 12) {
                    if let favicon = favicon {
                        Image(uiImage: favicon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 18, height: 18)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }

                    if let feed = feedManager.feed(forArticle: article) {
                        Text(feed.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let author = article.author {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(author)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let date = article.publishedDate {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(date, format: .dateTime.month().day().year())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                    CachedAsyncImage(url: url) {
                        Rectangle()
                            .fill(.secondary.opacity(0.1))
                            .frame(height: 200)
                    }
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if isExtracting {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else if let text = displayText {
                    Text(text)
                        .font(.body)
                        .foregroundStyle(.primary)
                }

                if !isExtracting && displayText != nil {
                    Button {
                        triggerTranslation()
                    } label: {
                        Label(
                            String(localized: "Article.Translate"),
                            systemImage: "translate"
                        )
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    if let url = URL(string: article.url) {
                        openURL(url)
                    }
                } label: {
                    Label(String(localized: "Article.OpenInBrowser"),
                          systemImage: "safari")
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
            .padding()
        }
        .sakuraBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    feedManager.toggleBookmark(article)
                } label: {
                    Image(systemName: article.isBookmarked ? "bookmark.fill" : "bookmark")
                }
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItemGroup(placement: .topBarTrailing) {
                ShareLink(item: URL(string: article.url)!) {
                    Label(String(localized: "Article.Share"), systemImage: "square.and.arrow.up")
                }
            }
        }
        .task {
            feedManager.markRead(article)
            if let feed = feedManager.feed(forArticle: article) {
                favicon = await FaviconCache.shared.favicon(for: feed.domain)
            }
            await extractArticleContent()
        }
        .translationTask(translationConfig) { session in
            let source = extractedText ?? article.summary ?? ""
            guard !source.isEmpty else { return }
            do {
                let response = try await session.translate(source)
                translatedText = response.targetText
            } catch {
                // Translation failed; user can retry
            }
        }
    }

    private func extractArticleContent() async {
        isExtracting = true
        defer { isExtracting = false }

        if let cached = try? DatabaseManager.shared.cachedArticleContent(for: article.id),
           !cached.isEmpty {
            extractedText = cached
            return
        }

        if let content = article.content, !content.isEmpty {
            let text = ArticleExtractor.extractText(fromHTML: content)
            if let text, !text.isEmpty {
                extractedText = text
                try? DatabaseManager.shared.cacheArticleContent(text, for: article.id)
                return
            }
        }

        if let url = URL(string: article.url) {
            let text = await ArticleExtractor.extractText(fromURL: url)
            extractedText = text
            if let text, !text.isEmpty {
                try? DatabaseManager.shared.cacheArticleContent(text, for: article.id)
            }
        }
    }

    private func triggerTranslation() {
        if translationConfig == nil {
            translationConfig = .init()
        } else {
            translationConfig?.invalidate()
        }
    }
}
