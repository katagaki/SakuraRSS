import Foundation
import SwiftSoup

extension ArticleExtractor {

    /// Promotes `<audio>` elements to `{{AUDIO}}url{{/AUDIO}}` marker
    /// paragraphs so noise removal doesn't strip them and they survive
    /// HTML-to-text conversion intact.
    static func promoteAudioEmbeds(in doc: Document, baseURL: URL? = nil) {
        guard let audios = try? doc.select("audio") else { return }
        for audio in audios {
            guard let resolved = audioSource(from: audio, baseURL: baseURL) else {
                _ = try? audio.remove()
                continue
            }
            let marker = "{{AUDIO}}\(resolved){{/AUDIO}}"
            let target = outermostAudioWrapper(for: audio)
            do {
                try target.before("<p>\(marker)</p>")
                try target.remove()
            } catch {
            }
        }
    }

    private static func audioSource(from audio: Element, baseURL: URL?) -> String? {
        let direct = (try? audio.attr("src")) ?? ""
        if !direct.isEmpty, let resolved = resolveURL(direct, against: baseURL) {
            return resolved
        }
        if let sources = try? audio.select("source[src]") {
            for source in sources {
                let src = (try? source.attr("src")) ?? ""
                if src.isEmpty { continue }
                if let resolved = resolveURL(src, against: baseURL) {
                    return resolved
                }
            }
        }
        return nil
    }

    private static func outermostAudioWrapper(for element: Element) -> Element {
        let wrapperTags: Set<String> = ["figure", "div", "aside", "p", "span"]
        var current: Element = element
        while let parent = current.parent(),
              wrapperTags.contains(parent.tagName().lowercased()) {
            let siblings = parent.children().filter { $0 !== current }
            let siblingHasText = siblings.contains { sibling in
                let text = ((try? sibling.text()) ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return !text.isEmpty
            }
            if siblingHasText { break }
            let ownText = parent.ownText()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !ownText.isEmpty { break }
            current = parent
        }
        return current
    }
}
