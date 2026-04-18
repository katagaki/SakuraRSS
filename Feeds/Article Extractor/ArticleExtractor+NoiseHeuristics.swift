import Foundation
import SwiftSoup

extension ArticleExtractor {

    /// Removes lists where most items are just links (likely navigation menus).
    static func removeMenuLists(from element: Element) {
        do {
            let lists = try element.select("ul, ol")
            for list in lists {
                let items = try list.select("li")
                guard items.size() > 2 else { continue }
                // Count link-bearing items rather than total <a>s / total <li>s.
                // A decorative <li> (close button, label, search box) alongside
                // real link items would otherwise defeat a strict ratio check.
                var linkItems = 0
                for item in items where (try? item.select("a").first()) != nil {
                    linkItems += 1
                }
                guard linkItems >= 3 else { continue }
                let totalText = try list.text()
                let avgTextPerLinkItem = totalText.count / max(linkItems, 1)
                // Two signals: mostly-links, and short labels per link.
                let linkDensity = Double(linkItems) / Double(items.size())
                if linkDensity >= 0.6 && avgTextPerLinkItem < 50 {
                    try list.remove()
                }
            }
        } catch {
            // Menu detection is best-effort; failures are non-critical
        }
    }

    /// Detects and removes "suggestion" sections: a heading like
    /// "Related Articles" or "You May Also Like" followed by a link-heavy block.
    static func removeSuggestionSections(from element: Element) {
        let suggestionHeadingPatterns = [
            "related", "recommended", "suggested", "you may also",
            "you might also", "more from", "more stories",
            "more articles", "don't miss", "also read",
            "read next", "read more", "trending", "popular",
            "most read", "top stories", "further reading",
            "editors' picks", "editor's pick", "latest news",
            "what to read next", "up next", "around the web"
        ]

        do {
            let headings = try element.select("h2, h3, h4, h5, h6")
            for heading in headings {
                let text = (try? heading.text())?.lowercased() ?? ""
                let isSuggestionHeading = suggestionHeadingPatterns.contains { text.contains($0) }
                guard isSuggestionHeading else { continue }

                if let parent = heading.parent(),
                   parent.tagName().lowercased() != "body",
                   !["article", "main"].contains(parent.tagName().lowercased()) {
                    let parentLinks = (try? parent.select("a"))?.size() ?? 0
                    if parentLinks >= 2 {
                        try parent.remove()
                        continue
                    }
                }

                var sibling = try heading.nextElementSibling()
                try heading.remove()
                while let current = sibling {
                    let tag = current.tagName().lowercased()
                    if ["h1", "h2", "h3", "h4", "h5", "h6"].contains(tag) {
                        break
                    }
                    let next = try current.nextElementSibling()
                    try current.remove()
                    sibling = next
                }
            }
        } catch {
            // Best-effort; failures are non-critical
        }
    }

    /// Heuristic: a container whose children are overwhelmingly icon-only
    /// links or buttons (tiny text payload, many links) is almost always a
    /// share toolbar, floating action bar, or pagination strip.
    static func removeIconToolbars(from element: Element) {
        do {
            let candidates = try element.select("div, nav, section, ul")
            for candidate in candidates {
                let anchorCount = (try? candidate.select("a").size()) ?? 0
                let buttonCount = (try? candidate.select("button").size()) ?? 0
                let actionableCount = anchorCount + buttonCount
                guard actionableCount >= 3 else { continue }

                let text = (try? candidate.text()) ?? ""
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                // Average visible characters per actionable element - share
                // toolbars and pagination rows score <=4 (often 0 with SVG
                // icons); real prose scores much higher.
                let avgTextPerAction = trimmed.count / max(actionableCount, 1)
                guard avgTextPerAction <= 4 else { continue }

                // Only remove shallow containers: if they wrap long-form
                // content alongside the toolbar, we'd nuke too much.
                let paragraphCount = (try? candidate.select("p").size()) ?? 0
                guard paragraphCount == 0 else { continue }

                try candidate.remove()
            }
        } catch {
            // Best-effort; failures are non-critical
        }
    }

    /// Heuristic: a short container containing only links/buttons whose
    /// href or text references a sharing target (facebook.com/sharer,
    /// twitter.com/intent, mailto:?subject=…, window.print, …).
    static func removeShareButtonClusters(from element: Element) {
        let shareTargetPatterns = [
            "facebook.com/sharer", "facebook.com/share",
            "twitter.com/intent", "twitter.com/share",
            "x.com/intent", "x.com/share",
            "linkedin.com/share", "linkedin.com/sharing",
            "pinterest.com/pin", "reddit.com/submit",
            "mailto:?", "sms:?", "whatsapp://send",
            "t.me/share", "telegram.me/share",
            "wa.me/?", "api.whatsapp.com/send",
            "javascript:window.print", "window.print()",
            "service.weibo.com", "bsky.app/intent/compose"
        ]
        do {
            let candidates = try element.select("div, ul, nav, section, aside")
            for candidate in candidates {
                guard let anchors = try? candidate.select("a"), anchors.size() >= 2 else {
                    continue
                }
                var sharers = 0
                for anchor in anchors {
                    let href = ((try? anchor.attr("href")) ?? "").lowercased()
                    if shareTargetPatterns.contains(where: href.contains) {
                        sharers += 1
                    }
                }
                let ratio = Double(sharers) / Double(anchors.size())
                guard sharers >= 2 && ratio >= 0.5 else { continue }
                // Only drop shallow wrappers - refuse to delete a sidebar
                // that happens to include a couple of share links.
                let paragraphCount = (try? candidate.select("p").size()) ?? 0
                guard paragraphCount <= 1 else { continue }
                try candidate.remove()
            }
        } catch {
            // Best-effort; failures are non-critical
        }
    }

    /// Removes wrapper `<div>`/`<section>`/`<aside>` elements that contain
    /// no text, no images, and no video - usually leftover placeholder
    /// shells after ads or share buttons were stripped.
    static func removeEmptyContainers(from element: Element) {
        do {
            let candidates = try element.select(
                "div, section, aside, header, footer, span"
            )
            // Iterate in reverse so deleting a parent doesn't invalidate
            // positions of already-seen children.
            for candidate in candidates.array().reversed() {
                let text = ((try? candidate.text()) ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let hasMedia = ((try? candidate.select(
                    "img, picture, video, audio, svg, iframe, source"
                ).size()) ?? 0) > 0
                if text.isEmpty && !hasMedia {
                    try? candidate.remove()
                }
            }
        } catch {
            // Best-effort; failures are non-critical
        }
    }
}
