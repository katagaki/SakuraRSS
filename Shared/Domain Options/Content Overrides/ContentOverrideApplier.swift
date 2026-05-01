import Foundation

/// Applies a feed's `ContentOverride` to a stored article by remapping fields for display.
nonisolated enum ContentOverrideApplier {

    static func applying(to article: Article, override: ContentOverride?) -> Article {
        guard let override, override.isActive else { return article }
        let source = ArticleFieldValues(
            title: article.title,
            summary: article.summary,
            content: article.content,
            author: article.author
        )
        var result = article
        applyTitle(field: override.titleField, source: source, into: &result.title)
        applyOptional(field: override.bodyField, source: source, into: &result.summary)
        applyOptional(field: override.authorField, source: source, into: &result.author)
        return result
    }

    private static func applyTitle(
        field: ContentOverrideField,
        source: ArticleFieldValues,
        into target: inout String
    ) {
        switch field {
        case .default:
            return
        case .disabled:
            target = ""
        case .title, .summary, .content, .author:
            guard let raw = source.value(for: field) else { return }
            let cleaned = stripContentMarkers(raw)
            if !cleaned.isEmpty {
                target = cleaned
            }
        }
    }

    /// Removes block markers (`{{IMG}}…{{/IMG}}`, etc.) and collapses whitespace
    /// so a body/content value can be safely promoted into a plain-text title.
    private static func stripContentMarkers(_ text: String) -> String {
        let pairedTags = ["IMG", "IMGLINK", "VIDEO", "AUDIO", "YOUTUBE", "XPOST", "EMBED", "TABLE", "MATH"]
        var result = text
        for tag in pairedTags {
            let pattern = "\\{\\{\(tag)\\}\\}.+?\\{\\{/\(tag)\\}\\}"
            result = result.replacingOccurrences(
                of: pattern, with: " ", options: [.regularExpression, .caseInsensitive]
            )
        }
        for marker in ["{{CODE}}", "{{/CODE}}", "{{SUP}}", "{{/SUP}}", "{{SUB}}", "{{/SUB}}"] {
            result = result.replacingOccurrences(of: marker, with: "")
        }
        result = result.replacingOccurrences(
            of: "\\s+", with: " ", options: .regularExpression
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func applyOptional(
        field: ContentOverrideField,
        source: ArticleFieldValues,
        into target: inout String?
    ) {
        switch field {
        case .default:
            return
        case .disabled:
            target = nil
        case .title, .summary, .content, .author:
            target = source.value(for: field)
        }
    }

    private struct ArticleFieldValues {
        let title: String
        let summary: String?
        let content: String?
        let author: String?

        func value(for field: ContentOverrideField) -> String? {
            switch field {
            case .default, .disabled: return nil
            case .title: return title
            case .summary: return summary
            case .content: return content
            case .author: return author
            }
        }
    }
}
