import SwiftUI

/// Inline "Open" and "Mark Read" buttons rendered under the article title
/// in the Feed (Compact) style.
struct CompactFeedArticleRowActions: View {

    @Environment(FeedManager.self) private var feedManager
    @Environment(\.openURL) private var openURL
    @AppStorage("YouTube.OpenMode") private var youTubeOpenMode: YouTubeOpenMode = .inAppPlayer

    let article: Article
    let opensInExternalApp: Bool
    var onShowYouTubePlayer: (() -> Void)?
    var onShowSafari: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            openButton
            markReadButton
            Spacer(minLength: 0)
        }
    }

    private var openButtonSystemName: String {
        if article.isYouTubeURL && YouTubeHelper.isAppInstalled {
            return "play.rectangle"
        }
        return opensInExternalApp ? "arrow.up.forward.app" : "safari"
    }

    private var openButtonTitle: String {
        opensInExternalApp
            ? String(localized: "OpenInApp", table: "Articles")
            : String(localized: "OpenInBrowser", table: "Articles")
    }

    @ViewBuilder
    private var openButton: some View {
        Button {
            if article.isYouTubeURL && youTubeOpenMode == .inAppPlayer {
                onShowYouTubePlayer?()
            } else if article.isYouTubeURL && youTubeOpenMode == .youTubeApp {
                YouTubeHelper.openInApp(url: article.url)
            } else if article.isYouTubeURL && youTubeOpenMode == .browser {
                onShowSafari()
            } else if let url = URL(string: article.url) {
                openURL(url)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: openButtonSystemName)
                Text(openButtonTitle)
                    .lineLimit(1)
            }
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(.secondary.opacity(0.15), in: .capsule)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    @ViewBuilder
    private var markReadButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            feedManager.toggleRead(article)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: article.isRead ? "envelope" : "envelope.open")
                    .offset(y: article.isRead ? 0 : -1)
                Text(
                    article.isRead
                        ? String(localized: "Article.MarkUnread", table: "Articles")
                        : String(localized: "Article.MarkRead", table: "Articles")
                )
                .lineLimit(1)
            }
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(.secondary.opacity(0.15), in: .capsule)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
}
