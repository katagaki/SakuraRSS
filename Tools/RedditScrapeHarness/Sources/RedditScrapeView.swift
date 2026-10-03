import SwiftUI
import WebKit

struct RedditScrapeView: View {
    @State private var model = RedditScrapeModel()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Menu("r/\(model.subreddit)") {
                    ForEach(["iOSBeta", "swift", "apple", "technology"], id: \.self) { subreddit in
                        Button("r/\(subreddit)") { model.load(subreddit: subreddit) }
                    }
                }
                Menu(model.sort) {
                    ForEach(["new", "hot", "top", "rising", "controversial"], id: \.self) { sort in
                        Button(sort) { model.load(sort: sort) }
                    }
                }
                Button("Scrape") { model.scrape() }
                Button("More") { model.loadMore() }
                Button("Headless") { model.runHeadless() }
                Button("Next") { model.loadNextPage() }
                Button("Reload") { model.reload() }
            }
            .padding(10)

            Text(model.status)
                .font(.caption)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)

            RedditHarnessWebView(webView: model.webView)
                .frame(height: 330)

            List(model.posts) { post in
                VStack(alignment: .leading, spacing: 4) {
                    Text(post.title).font(.headline)
                    Text("\(post.id) · \(post.author) · \(post.created)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(post.url).font(.caption2).textSelection(.enabled)
                }
            }
            .overlay {
                if model.posts.isEmpty {
                    ContentUnavailableView("No posts extracted", systemImage: "tray")
                }
            }
        }
    }
}

private struct RedditHarnessWebView: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ view: WKWebView, context: Context) {}
}
