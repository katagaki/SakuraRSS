import SwiftUI

extension PodcastEpisodeView {

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
