import SwiftUI

extension ArticleDetailView {

    @ViewBuilder
    var conversationsSection: some View {
        if shouldShowConversationsSection {
            VStack(alignment: .leading, spacing: 16) {
                Divider()
                    .padding(.horizontal)

                Button {
                    if let conversationURL {
                        openURL(conversationURL)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Label(
                            String(localized: "Conversations.Title", table: "Articles"),
                            systemImage: "bubble.left.and.bubble.right"
                        )
                        .font(.title3)
                        .fontWeight(.bold)
                        if conversationURL != nil {
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(conversationURL == nil)

                if isLoadingConversation && conversationComments.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                        .transition(.blurReplace)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(conversationComments.enumerated()), id: \.element.id) { index, comment in
                            if index > 0 {
                                Divider()
                            }
                            ConversationCommentRow(comment: comment)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private var shouldShowConversationsSection: Bool {
        if isLoadingConversation { return true }
        return !conversationComments.isEmpty
    }

    /// Loads cached comments first, then fetches fresh comments on first open.
    /// Ephemeral articles bypass the cache: their `id == 0` would collide in
    /// the per-article comment table.
    func loadConversationInBackground() {
        let feed = feedManager.feed(forArticle: article)
        guard let source = CommentSourceRegistry.source(for: article, in: feed) else {
            log("Comments", "no source for article id=\(article.id) feed=\(feed?.title ?? "nil")")
            return
        }
        let url = source.commentsURL(for: article, in: feed)
        conversationURL = url
        log("Comments", "source=\(source.providerID) article id=\(article.id) url=\(url?.absoluteString ?? "nil")")

        let database = DatabaseManager.shared
        let articleID = article.id
        let useCache = !article.isEphemeral

        if useCache {
            if let cached = try? database.cachedComments(forArticleID: articleID),
               !cached.isEmpty {
                log("Comments", "cache hit article id=\(articleID) count=\(cached.count)")
                conversationComments = cached
                return
            }

            if (try? database.hasFetchedComments(forArticleID: articleID)) == true {
                log("Comments", "cache empty (already fetched, no comments) article id=\(articleID)")
                return
            }
        }

        let articleValue = article
        let limit = Self.topConversationCount
        isLoadingConversation = true
        log("Comments", "fetch begin article id=\(articleID) limit=\(limit) ephemeral=\(!useCache)")
        Task { [feed] in
            defer {
                isLoadingConversation = false
                log("Comments", "fetch end article id=\(articleID) shown=\(conversationComments.count)")
            }
            do {
                let started = Date()
                let fetched = try await source.fetchComments(
                    for: articleValue, in: feed, limit: limit
                )
                let elapsed = String(format: "%.2fs", Date().timeIntervalSince(started))
                log("Comments", "fetch ok article id=\(articleID) count=\(fetched.count) in \(elapsed)")
                if useCache {
                    do {
                        try database.replaceComments(fetched, forArticleID: articleID)
                        log("Comments", "cache write article id=\(articleID) count=\(fetched.count)")
                    } catch {
                        log("Comments", "cache write failed article id=\(articleID) error=\(error)")
                    }
                    if let stored = try? database.cachedComments(forArticleID: articleID) {
                        conversationComments = stored
                    }
                } else {
                    conversationComments = fetched.enumerated().map { index, item in
                        Comment.fromFetched(item, rank: index)
                    }
                }
            } catch {
                log("Comments", "fetch failed article id=\(articleID) error=\(error)")
            }
        }
    }

    static let topConversationCount = 3
}
