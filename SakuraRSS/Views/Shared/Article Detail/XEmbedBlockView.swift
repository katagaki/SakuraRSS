import SwiftUI

/// Inline X (Twitter) embed used when an article body contains a
/// `{{XPOST}}<url>{{/XPOST}}` marker.  When the reader is signed in to X
/// and the X profile feeds lab is enabled, the tweet text is fetched via
/// the same scraper the profile-feed feature uses; otherwise the embed
/// falls back to a tappable link card that opens the original post.
struct XEmbedBlockView: View {

    let url: URL

    @State private var tweet: ParsedTweet?
    @State private var isLoading = false
    @State private var loadFailed = false

    private var tweetID: String? {
        XProfileScraper.extractTweetID(from: url)
    }

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.secondary.opacity(0.2), lineWidth: 1)
            )
            .contentShape(.rect(cornerRadius: 12))
            .onTapGesture {
                UIApplication.shared.open(url)
            }
            .task { await loadTweet() }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if let tweet {
                Text(tweet.text)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .textSelection(.enabled)

                if let imageURL = tweet.imageURL, let url = URL(string: imageURL) {
                    CachedAsyncImage(url: url) {
                        Rectangle()
                            .fill(.secondary.opacity(0.1))
                            .frame(height: 160)
                    }
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            } else if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(String(localized: "Article.Embed.XLoading", table: "Articles"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(String(localized: "Article.Embed.XOpenPost", table: "Articles"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 4) {
                Text(url.absoluteString)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right.square")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 6) {
            if let tweet {
                Text(tweet.author)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("@\(tweet.authorHandle)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text(String(localized: "Article.Embed.XPost", table: "Articles"))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let date = tweet?.publishedDate {
                RelativeTimeText(date: date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func loadTweet() async {
        guard tweet == nil, !loadFailed, !isLoading,
              let tweetID,
              UserDefaults.standard.bool(forKey: "Labs.XProfileFeeds") else {
            return
        }
        guard await XProfileScraper.hasXSession() else { return }
        isLoading = true
        defer { isLoading = false }
        let scraper = XProfileScraper()
        if let parsed = await scraper.fetchSingleTweet(tweetID: tweetID) {
            tweet = parsed
        } else {
            loadFailed = true
        }
    }
}
