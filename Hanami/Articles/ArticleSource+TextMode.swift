import Foundation

public nonisolated extension ArticleSource {
    /// Translates the `sakura://open` text-mode override into the same
    /// `ArticleSource` enum used by the per-feed UserDefaults setting.
    init(textMode: OpenArticleRequest.TextMode) {
        switch textMode {
        case .auto: self = .automatic
        case .fetch: self = .fetchText
        case .extract: self = .extractText
        }
    }
}
