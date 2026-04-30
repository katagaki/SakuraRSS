import Foundation

/// Applies a feed's `ContentOverride` to a parsed or stored article by remapping fields.
nonisolated enum ContentOverrideApplier {

    static func applying(to article: ParsedArticle, override: ContentOverride?) -> ParsedArticle {
        guard let override, override.isActive else { return article }
        let source = ArticleFieldValues(
            title: article.title,
            summary: article.summary,
            content: article.content,
            author: article.author
        )
        var result = article
        if let newTitle = source.value(for: override.titleField), !newTitle.isEmpty {
            result.title = newTitle
        }
        if override.bodyField != .default {
            result.summary = source.value(for: override.bodyField)
        }
        if override.authorField != .default {
            result.author = source.value(for: override.authorField)
        }
        return result
    }

    static func applying(to article: Article, override: ContentOverride?) -> Article {
        guard let override, override.isActive else { return article }
        let source = ArticleFieldValues(
            title: article.title,
            summary: article.summary,
            content: article.content,
            author: article.author
        )
        var result = article
        if let newTitle = source.value(for: override.titleField), !newTitle.isEmpty {
            result.title = newTitle
        }
        if override.bodyField != .default {
            result.summary = source.value(for: override.bodyField)
        }
        if override.authorField != .default {
            result.author = source.value(for: override.authorField)
        }
        return result
    }

    private struct ArticleFieldValues {
        let title: String
        let summary: String?
        let content: String?
        let author: String?

        func value(for field: ContentOverrideField) -> String? {
            switch field {
            case .default: return nil
            case .title: return title
            case .summary: return summary
            case .content: return content
            case .author: return author
            }
        }
    }
}
