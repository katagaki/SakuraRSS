import SwiftUI

/// Inline "Open" and "Mark Read" buttons rendered under the article title
/// in the Feed (Compact) style.
struct CompactFeedArticleRowActions: View {

    @Environment(FeedManager.self) private var feedManager
    @Environment(\.openURL) private var openURL
    @AppStorage("YouTube.OpenMode") private var youTubeOpenMode: YouTubeOpenMode = .inAppPlayer

    let article: Article
    let opensInExternalApp: Bool
    var onShowSafari: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            openButton
                .disabled(!article.hasLink)
            markReadButton
            Spacer(minLength: 0)
        }
    }

    private var openButtonSystemName: String {
        if article.isYouTubeURL && YouTubeHelper.isAppInstalled {
            return "play.rectangle"
        }
        return opensInExternalApp ? "arrow.up.forward.app" : "arrow.up.forward.square"
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
                feedManager.markRead(article)
                MediaPresenter.shared.presentYouTube(article)
            } else if article.isYouTubeURL && youTubeOpenMode == .youTubeApp {
                YouTubeHelper.openInApp(url: article.url)
            } else if article.isYouTubeURL && youTubeOpenMode == .browser {
                onShowSafari()
            } else if let url = URL(string: article.url) {
                openURL(url)
            }
        } label: {
            Image(systemName: openButtonSystemName)
                .font(.subheadline.weight(.semibold))
                .frame(minWidth: 36, minHeight: 36)
                .background(.secondary.opacity(0.15), in: .capsule)
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.circle)
        .foregroundStyle(.primary)
    }

    @ViewBuilder
    private var markReadButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            feedManager.toggleRead(article)
        } label: {
            Image(systemName: feedManager.isRead(article) ? "envelope" : "envelope.open")
                .offset(y: feedManager.isRead(article) ? 0 : -1)
                .font(.subheadline.weight(.semibold))
                .frame(minWidth: 36, minHeight: 36)
                .background(.secondary.opacity(0.15), in: .capsule)
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.circle)
        .foregroundStyle(.primary)
    }
}
