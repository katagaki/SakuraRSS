import SwiftUI

/// Inline X embed for `{{XPOST}}` markers; fetches the tweet when signed in, else shows a link card.
struct XEmbedBlockView: View {

    let url: URL
    /// Routes the tap so the parent can honour the user's
    /// `Reading.LinkOpenMode` (browser vs in-app viewer). Falls back to the
    /// system browser when no handler is supplied.
    var onTap: ((URL) -> Void)?

    @State private var tweet: ParsedTweet?
    @State private var isLoading = false
    @State private var loadFailed = false
    @State private var imageAspectRatio: CGFloat?
    @State private var imageSize: CGSize?

    private var tweetID: String? {
        XProfileFetcher.extractTweetID(from: url)
    }

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(uiColor: .secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.primary.opacity(0.2), lineWidth: 0.5)
            }
            .contentShape(.rect(cornerRadius: 12))
            .onTapGesture {
                if let onTap {
                    onTap(url)
                } else {
                    UIApplication.shared.open(url)
                }
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
                    CachedAsyncImage(url: url, onImageLoaded: { image in
                        imageAspectRatio = image.size.width / image.size.height
                        imageSize = image.size
                    }, placeholder: {
                        Rectangle()
                            .fill(.secondary.opacity(0.1))
                    })
                    .aspectRatio(imageAspectRatio ?? (16.0 / 9.0), contentMode: .fit)
                    .frame(maxWidth: imageSize?.width)
                    .clipShape(.rect(cornerRadius: 8))
                    .frame(maxWidth: .infinity, alignment: .center)
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
                Image(systemName: "arrow.up.forward.square")
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
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("@\(tweet.authorHandle)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text(String(localized: "Article.Embed.XPost", table: "Articles"))
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let date = tweet?.publishedDate {
                RelativeTimeText(date: date)
                    .font(.subheadline)
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
        guard XProfileFetcher.hasSession() else { return }
        isLoading = true
        defer { isLoading = false }
        let fetcher = XProfileFetcher()
        if let parsed = await fetcher.fetchSingleTweet(tweetID: tweetID) {
            tweet = parsed
        } else {
            loadFailed = true
        }
    }
}
