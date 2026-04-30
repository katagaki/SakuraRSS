import SwiftUI

extension YouTubePlayerView {

    @ToolbarContentBuilder
    var playerToolbar: some ToolbarContent {
        if showsDismissButton {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismissSheet()
                } label: {
                    Image(systemName: "chevron.down")
                }
                .accessibilityLabel(String(localized: "Article.Dismiss", table: "Articles"))
            }
        }
        if let activityLabel = toolbarActivityLabel {
            ToolbarItem(placement: .principal) {
                ToolbarActivityIndicator(label: activityLabel)
            }
        }
        if !chapters.isEmpty {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ChapterMenu(chapters: chapters, onSelect: seek(to:))
                    .equatable()
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            if !article.isEphemeral {
                Button {
                    isBookmarked.toggle()
                    feedManager.toggleBookmark(article)
                } label: {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                }
            }
            overflowMenu
        }
    }

    var toolbarActivityLabel: String? {
        if isTranslating {
            return String(localized: "Article.Translating", table: "Articles")
        }
        if isSummarizing {
            return String(localized: "Article.Summarizing", table: "Articles")
        }
        return nil
    }
}
