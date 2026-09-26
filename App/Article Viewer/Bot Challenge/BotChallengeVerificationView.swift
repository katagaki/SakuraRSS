import SwiftUI

/// Shows the bot challenge in a visible WebView so the user can pass it; the
/// clearance cookie then lets `WebViewExtractor` load the page on retry.
struct BotChallengeVerificationView: View {

    let url: URL
    let onVerified: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                BotChallengeWebView(url: url, isLoading: $isLoading) {
                    dismiss()
                    onVerified()
                }
                .ignoresSafeArea(edges: .bottom)

                if isLoading {
                    ProgressView()
                }
            }
            .navigationTitle(String(localized: "Article.BotChallenge.Title", table: "Articles"))
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .cancel) { dismiss() }
                }
            }
        }
    }
}
