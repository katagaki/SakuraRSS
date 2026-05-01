import SwiftUI

/// Previews the in-app viewer with three random items from the feed.
/// Top-trailing toolbar exposes only chevron prev/next split by ToolbarSpacer.
struct ArticleViewerPreviewView: View {

    @Environment(FeedManager.self) var feedManager
    let feedID: Int64

    @State private var sample: [Article] = []
    @State private var currentIndex: Int = 0

    var feed: Feed? {
        feedManager.feedsByID[feedID]
    }

    var body: some View {
        Group {
            if let current = sample[safe: currentIndex] {
                ArticleDetailView(article: current, previewMode: true)
                    .id(current.id)
            } else {
                placeholder
            }
        }
        .navigationTitle(String(localized: "FeedEdit.Preview.ArticleTitle", table: "Feeds"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if currentIndex > 0 { currentIndex -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(currentIndex <= 0)
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if currentIndex < sample.count - 1 { currentIndex += 1 }
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(currentIndex >= sample.count - 1)
            }
        }
        .onAppear { loadSampleIfNeeded() }
    }

    @ViewBuilder
    private var placeholder: some View {
        ContentUnavailableView {
            Label(String(localized: "Empty.Title", table: "Articles"),
                  systemImage: "doc.text")
        } description: {
            Text(String(localized: "Empty.Description", table: "Articles"))
        }
    }

    private func loadSampleIfNeeded() {
        guard sample.isEmpty, let feed else { return }
        let pool = feedManager.articles(for: feed)
        sample = pool.shuffled().prefix(3).map { feedManager.article(byID: $0.id) ?? $0 }
        currentIndex = 0
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
