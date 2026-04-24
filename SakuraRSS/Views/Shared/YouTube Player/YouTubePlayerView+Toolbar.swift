import SwiftUI

extension YouTubePlayerView {

    @ToolbarContentBuilder
    var playerToolbar: some ToolbarContent {
        if !chapters.isEmpty {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ChapterMenu(chapters: chapters, onSelect: seek(to:))
                    .equatable()
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                isBookmarked.toggle()
                feedManager.toggleBookmark(article)
            } label: {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
            }
        }
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        ToolbarItemGroup(placement: .topBarTrailing) {
            if let shareURL = URL(string: article.url) {
                ShareLink(item: shareURL) {
                    Label(
                        String(localized: "Article.Share", table: "Articles"),
                        systemImage: "square.and.arrow.up"
                    )
                }
            }
        }
    }
}
