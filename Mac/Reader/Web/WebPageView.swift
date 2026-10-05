import Hanami
import SwiftUI

/// Content shown as a web page, as the feed or folder's Open In setting, or
/// the link that opened it, asks for.
struct WebPageView: View {

    let article: Article
    let url: URL
    let style: WebPageStyle
    let activity: BrowserPageActivity
    @State private var isLoading = true
    @State private var reloadTrigger = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(article.isEphemeral ? (url.host() ?? url.absoluteString) : article.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Button(String(localized: "Page.Reload", table: "Mac"), systemImage: "arrow.clockwise") {
                    reloadTrigger &+= 1
                }
                Button(String(localized: "Article.OpenInBrowser", table: "Articles"), systemImage: "safari") {
                    NSWorkspace.shared.open(url)
                }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            Divider()
            WebPageWebView(url: url, style: style, reloadTrigger: reloadTrigger, isLoading: $isLoading)
                .opacity(isLoading && style != .page ? 0 : 1)
                .overlay {
                    if isLoading && style != .page {
                        ProgressView()
                    }
                }
        }
        .onChange(of: isLoading, initial: true) { _, loading in
            activity.isExtractingContent = loading
        }
        .onDisappear {
            activity.isExtractingContent = false
        }
    }
}
