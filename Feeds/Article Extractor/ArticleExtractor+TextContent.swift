import Foundation
import SwiftSoup

extension ArticleExtractor {

    static let imgOpenPlaceholder = "{{SAKURA_IMG_OPEN}}"
    static let imgClosePlaceholder = "{{SAKURA_IMG_CLOSE}}"
    static let imgLinkOpenPlaceholder = "{{SAKURA_IMGLINK_OPEN}}"
    static let imgLinkClosePlaceholder = "{{SAKURA_IMGLINK_CLOSE}}"
    static let brPlaceholder = "{{SAKURA_BR}}"
    static let linkOpenPlaceholder = "{{SAKURA_LINK_OPEN}}"
    static let linkMidPlaceholder = "{{SAKURA_LINK_MID}}"
    static let linkClosePlaceholder = "{{SAKURA_LINK_CLOSE}}"
    static let boldOpenPlaceholder = "{{SAKURA_BOLD_OPEN}}"
    static let boldClosePlaceholder = "{{SAKURA_BOLD_CLOSE}}"
    static let italicOpenPlaceholder = "{{SAKURA_ITALIC_OPEN}}"
    static let italicClosePlaceholder = "{{SAKURA_ITALIC_CLOSE}}"
    static let supOpenPlaceholder = "{{SAKURA_SUP_OPEN}}"
    static let supClosePlaceholder = "{{SAKURA_SUP_CLOSE}}"
    static let subOpenPlaceholder = "{{SAKURA_SUB_OPEN}}"
    static let subClosePlaceholder = "{{SAKURA_SUB_CLOSE}}"
    static let codeOpenPlaceholder = "{{SAKURA_CODE_OPEN}}"
    static let codeClosePlaceholder = "{{SAKURA_CODE_CLOSE}}"

    static let doubleLFPlaceholder = "{{SAKURA_DOUBLE_LF}}"
    static let singleLFPlaceholder = "{{SAKURA_SINGLE_LF}}"

    /// Extracts text from a block element, preserving `<br>` as newlines and `<a>` as Markdown links.
    static func textContent(of element: Element, baseURL: URL? = nil) throws -> String {
        promoteLazyImageSources(in: element)
        replaceImagesInDOM(in: element, baseURL: baseURL)
        var html = try element.html()
        // Strip <svg> entirely so icon-only anchors don't leak SVG markup
        // as "link text" through the link-replacement regex.
        html = html.replacingOccurrences(
            of: "<svg\\b[^>]*>[\\s\\S]*?</svg>",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        html = html.replacingOccurrences(
            of: "<br\\s*/?>(\\s*<br\\s*/?>)+",
            with: doubleLFPlaceholder,
            options: .regularExpression
        )
        html = html.replacingOccurrences(
            of: "<br\\s*/?>",
            with: singleLFPlaceholder,
            options: .regularExpression
        )
        // Preserve literal newlines before SwiftSoup's .text() strips them.
        html = html.replacingOccurrences(of: "\n\n", with: doubleLFPlaceholder)
        html = html.replacingOccurrences(of: "\n", with: singleLFPlaceholder)
        html = replaceLinkedImgTags(in: html, baseURL: baseURL)
        html = replaceImgTags(in: html, baseURL: baseURL)
        html = replaceLinkTags(in: html)
        html = replaceFormattingTags(in: html)
        let fragment = try SwiftSoup.parseBodyFragment(html)
        var text = try fragment.body()?.text() ?? ""
        text = text.replacingOccurrences(of: doubleLFPlaceholder, with: "\n\n")
        text = text.replacingOccurrences(of: singleLFPlaceholder, with: "\n")
        text = escapeBracketsInLinkText(text,
                                        open: linkOpenPlaceholder,
                                        mid: linkMidPlaceholder)
        // Escape literal markers before SAKURA placeholders become real ones.
        text = ArticleMarker.escape(text)
        text = convertPlaceholdersToMarkdown(text)
        text = stripInvalidURLSupSub(text)
        text = stripRemainingHTMLTags(text)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Rewrites lazy-loaded `<img>`/`<amp-img>` so `src` holds the best URL.
    static func promoteLazyImageSources(in element: Element) {
        guard let images = try? element.select("img, amp-img") else { return }
        for image in images {
            let currentSrc = (try? image.attr("src")) ?? ""
            let currentValid = !currentSrc.isEmpty
                && !currentSrc.hasPrefix("data:")
                && isLikelyContentImage(currentSrc)
            if currentValid { continue }
            guard let best = bestImageURL(from: image), !best.isEmpty else {
                continue
            }
            _ = try? image.attr("src", best)
        }
    }

    /// Replaces image elements in the DOM with text-only placeholders, keeping wrapping anchors.
    static func replaceImagesInDOM(in element: Element, baseURL: URL?) {
        guard let images = try? element.select("img, amp-img, picture") else {
            return
        }
        for image in images {
            guard image.parent() != nil else { continue }
            guard let rawSrc = bestImageURL(from: image), !rawSrc.isEmpty,
                  isLikelyContentImage(rawSrc),
                  let resolved = resolveURL(rawSrc, against: baseURL) else {
                _ = try? image.remove()
                continue
            }
            var target: Element = image
            var linkSuffix = ""
            if let parent = image.parent(),
               parent.tagName().lowercased() == "a",
               parent.children().size() == 1,
               let href = try? parent.attr("href"),
               !href.isEmpty,
               let resolvedHref = resolveURL(href, against: baseURL) {
                linkSuffix = "\(imgLinkOpenPlaceholder)\(resolvedHref)\(imgLinkClosePlaceholder)"
                target = parent
            }
            let placeholder = "\(imgOpenPlaceholder)\(resolved)\(linkSuffix)\(imgClosePlaceholder)"
            do {
                try target.before(placeholder)
                try target.remove()
            } catch {
                _ = try? target.remove()
            }
        }
    }
}
