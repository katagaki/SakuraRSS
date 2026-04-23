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
                // Count link-bearing items instead of total <a>s so a
                // decorative <li> won't defeat the ratio check.
                var linkItems = 0
                for item in items where (try? item.select("a").first()) != nil {
                    linkItems += 1
                }
                guard linkItems >= 3 else { continue }
                let totalText = try list.text()
                let avgTextPerLinkItem = totalText.count / max(linkItems, 1)
                let linkDensity = Double(linkItems) / Double(items.size())
                if linkDensity >= 0.6 && avgTextPerLinkItem < 50 {
                    try list.remove()
                }
            }
        } catch {
        }
    }

    /// Removes "Related Articles" / "You May Also Like" style suggestion sections.
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
        }
    }

    /// Removes containers dominated by icon-only links or buttons (share toolbars, pagination).
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
                // Icon toolbars score <=4 chars per action; prose scores higher.
                let avgTextPerAction = trimmed.count / max(actionableCount, 1)
                guard avgTextPerAction <= 4 else { continue }

                // Only strip shallow containers to avoid nuking prose alongside a toolbar.
                let paragraphCount = (try? candidate.select("p").size()) ?? 0
                guard paragraphCount == 0 else { continue }

                try candidate.remove()
            }
        } catch {
        }
    }

    /// Removes short containers of share links (facebook/sharer, twitter/intent, mailto, etc.).
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
                // Only drop shallow wrappers so sidebars with a few share
                // links aren't deleted wholesale.
                let paragraphCount = (try? candidate.select("p").size()) ?? 0
                guard paragraphCount <= 1 else { continue }
                try candidate.remove()
            }
        } catch {
        }
    }

    /// Removes wrapper containers with no text or media (leftover placeholder shells).
    static func removeEmptyContainers(from element: Element) {
        do {
            let candidates = try element.select(
                "div, section, aside, header, footer, span"
            )
            // Reverse iteration so parent removal doesn't invalidate positions.
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
        }
    }
}
