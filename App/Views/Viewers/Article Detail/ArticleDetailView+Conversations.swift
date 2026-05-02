import SwiftUI

extension ArticleDetailView {

    @ViewBuilder
    var conversationsSection: some View {
        if shouldShowConversationsSection {
            VStack(alignment: .leading, spacing: 16) {
                Divider()
                    .padding(.horizontal)

                Label(
                    String(localized: "Conversations.Title", table: "Articles"),
                    systemImage: "bubble.left.and.bubble.right"
                )
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal)

                if isLoadingConversation && conversationComments.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                        .transition(.blurReplace)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(conversationComments.enumerated()), id: \.element.id) { index, comment in
                            if index > 0 {
                                Divider()
                            }
                            ConversationCommentRow(comment: comment)
                        }
                    }
                    .padding(.horizontal)

                    if let conversationURL {
                        Button {
                            openURL(conversationURL)
                        } label: {
                            Text(String(localized: "Conversations.JoinButton",
                                        table: "Articles"))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal)
                        .padding(.top, 4)
                    }
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }

    private var shouldShowConversationsSection: Bool {
        guard !article.isEphemeral else { return false }
        if isLoadingConversation { return true }
        return !conversationComments.isEmpty
    }

    /// Loads cached comments first, then fetches fresh comments on first open.
    func loadConversationInBackground() {
        guard !article.isEphemeral else {
            log("Comments", "skip ephemeral article id=\(article.id)")
            return
        }
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

        let articleValue = article
        let limit = Self.topConversationCount
        isLoadingConversation = true
        log("Comments", "fetch begin article id=\(articleID) limit=\(limit)")
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
                do {
                    try database.replaceComments(fetched, forArticleID: articleID)
                    log("Comments", "cache write article id=\(articleID) count=\(fetched.count)")
                } catch {
                    log("Comments", "cache write failed article id=\(articleID) error=\(error)")
                }
                if let stored = try? database.cachedComments(forArticleID: articleID) {
                    conversationComments = stored
                }
            } catch {
                log("Comments", "fetch failed article id=\(articleID) error=\(error)")
            }
        }
    }

    static let topConversationCount = 3
}
