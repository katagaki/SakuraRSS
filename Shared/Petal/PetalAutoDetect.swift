import Foundation
import SwiftSoup

/// Heuristic selector inference for Web Feed recipes.
///
/// When the user hits "Auto-Detect" in the builder, this inspects
/// the fetched HTML for a repeating container pattern that looks
/// like a feed index: three or more sibling-like elements that
/// each wrap a link, a heading, and (optionally) an image.  If one
/// is found, it returns a partially-filled `PetalRecipe` with
/// suggested selectors the user can tweak.
///
/// The heuristic is intentionally conservative — it prefers
/// **returning nothing** over returning selectors that match the
/// wrong elements, because a bad auto-detect is a worse UX than
/// no auto-detect at all.
///
/// Algorithm, in broad strokes:
///
/// 1. Collect every `<a href>` on the page and walk up to three
///    ancestors to fingerprint the enclosing container (tag plus
///    first CSS class).
/// 2. Group the walk hits by fingerprint and score each one by
///    how many distinct anchors it contains.  Prefer fingerprints
///    with a class over bare tag names (class-less containers
///    like `div` tend to match way too loosely).
/// 3. Validate the winner by re-running the selector through
///    SwiftSoup and making sure it actually matches ≥ 3 elements.
/// 4. For the first matching container, probe common child
///    selectors for title / link / image / date / summary and
///    return whichever ones land.
nonisolated enum PetalAutoDetect {

    /// Hands back a partial recipe seeded with guessed selectors,
    /// or `nil` if no repeating pattern looks confident enough.
    static func detect(html: String, siteURL: String) -> PetalRecipe? {
        guard let document = try? SwiftSoup.parse(html, siteURL) else {
            return nil
        }

        guard let itemSelector = findItemSelector(in: document) else {
            return nil
        }
        // Re-select through the document so the first item we hand
        // to the child-selector probes is the same one a subsequent
        // `PetalEngine.parse` run would hit.
        guard let firstItem = try? document.select(itemSelector).first() else {
            return nil
        }

        let titleSelector = findTitleSelector(in: firstItem)
        let linkSelector = findLinkSelector(in: firstItem)
        let imageSelector = findImageSelector(in: firstItem)
        let dateSelector = findDateSelector(in: firstItem)
        let summarySelector = findSummarySelector(
            in: firstItem, excluding: titleSelector
        )

        let pageTitle = (try? document.title())?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return PetalRecipe(
            name: pageTitle.isEmpty
                ? (URL(string: siteURL)?.host ?? "Web Feed")
                : pageTitle,
            siteURL: siteURL,
            itemSelector: itemSelector,
            titleSelector: titleSelector,
            linkSelector: linkSelector,
            summarySelector: summarySelector,
            imageSelector: imageSelector,
            dateSelector: dateSelector,
            dateAttribute: dateSelector == "time" ? "datetime" : nil
        )
    }

    // MARK: - Item selector

    /// Scores candidate container fingerprints and picks the best.
    /// Returns `nil` if no fingerprint matched enough repeating
    /// elements to be worth surfacing.
    private static func findItemSelector(in document: Document) -> String? {
        guard let links = try? document.select("a[href]") else {
            return nil
        }

        // Fingerprint → (anchor count, element count)
        // `anchorCount` counts how many distinct `<a href>`s are
        // reachable under the fingerprint; `elementCount` is how
        // many siblings the fingerprint itself expands to when
        // re-selected from the document root.  We pick using both
        // because a fingerprint that matches 12 elements each
        // containing 1 link beats one that matches 2 elements each
        // containing 6 links.
        var anchorCounts: [String: Int] = [:]
        var seenAnchorsByFingerprint: [String: Set<Int>] = [:]

        for (linkIndex, link) in links.enumerated() {
            var current: Element? = link.parent()
            var depth = 0
            while let element = current, depth < 4 {
                let fingerprint = fingerprintFor(element)
                if !fingerprint.isEmpty, fingerprint != "html", fingerprint != "body" {
                    var seen = seenAnchorsByFingerprint[fingerprint] ?? []
                    if seen.insert(linkIndex).inserted {
                        anchorCounts[fingerprint, default: 0] += 1
                        seenAnchorsByFingerprint[fingerprint] = seen
                    }
                }
                current = element.parent()
                depth += 1
            }
        }

        // Only keep fingerprints that wrap ≥ 3 distinct anchors.
        // The cut-off rejects once-only nav bars and footer
        // groups that happen to show up in the same DOM path.
        let ranked = anchorCounts
            .filter { $0.value >= 3 }
            .sorted { lhs, rhs in
                let lhsHasClass = lhs.key.contains(".")
                let rhsHasClass = rhs.key.contains(".")
                if lhsHasClass != rhsHasClass { return lhsHasClass }
                return lhs.value > rhs.value
            }

        for candidate in ranked {
            guard let matched = try? document.select(candidate.key),
                  matched.count >= 3 else {
                continue
            }
            // Avoid overly permissive matches like `div` alone
            // that sweep in headers and sidebars.
            if matched.count > 60 && !candidate.key.contains(".") {
                continue
            }
            return candidate.key
        }
        return nil
    }

    /// Builds a compact CSS selector for an element: `tag.class`
    /// when it has a class, or just `tag` otherwise.  Multiple
    /// classes collapse to the first non-empty one because (a)
    /// chaining every class tends to produce brittle selectors
    /// and (b) many sites decorate elements with utility classes
    /// (Tailwind, Bootstrap) that don't survive layout changes.
    private static func fingerprintFor(_ element: Element) -> String {
        let tag = element.tagName().lowercased()
        let className = (try? element.className()) ?? ""
        let firstClass = className
            .split(separator: " ")
            .map(String.init)
            .first { !$0.isEmpty } ?? ""
        return firstClass.isEmpty ? tag : "\(tag).\(firstClass)"
    }

    // MARK: - Child selectors

    private static func findTitleSelector(in item: Element) -> String? {
        // Order matters — the first one that hits wins.
        let candidates = ["h1", "h2", "h3", "h4", ".title", "[itemprop=headline]"]
        for selector in candidates {
            if let element = try? item.select(selector).first(),
               let text = try? element.text(),
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return selector
            }
        }
        return nil
    }

    private static func findLinkSelector(in item: Element) -> String? {
        // If there's a single <a href> inside the item the engine's
        // fallback already handles it — no need to lock a brittle
        // selector in.  Only return a selector when there are
        // multiple anchors (e.g. author bylines + main link).
        guard let anchors = try? item.select("a[href]"), anchors.count > 1 else {
            return nil
        }
        // Prefer the anchor wrapping the title.
        if let titleLink = try? item.select("h1 a, h2 a, h3 a, h4 a").first(),
           (try? titleLink.attr("href"))?.isEmpty == false {
            return "h1 a, h2 a, h3 a, h4 a"
        }
        return "a[href]"
    }

    private static func findImageSelector(in item: Element) -> String? {
        guard let img = try? item.select("img[src]").first() else {
            return nil
        }
        // If there are multiple imgs, stick with the first.  No
        // selector tightening — the engine's default already picks
        // the first `<img src>` inside an item.
        if (try? img.attr("src"))?.isEmpty == false {
            return "img"
        }
        return nil
    }

    private static func findDateSelector(in item: Element) -> String? {
        if let time = try? item.select("time").first(),
           (try? time.attr("datetime"))?.isEmpty == false {
            return "time"
        }
        if let element = try? item.select("[datetime]").first(),
           (try? element.attr("datetime"))?.isEmpty == false {
            return "[datetime]"
        }
        return nil
    }

    private static func findSummarySelector(
        in item: Element,
        excluding titleSelector: String?
    ) -> String? {
        // The first paragraph inside the item is a reasonable
        // summary candidate, as long as it isn't the same element
        // we already picked for the title.
        guard let paragraph = try? item.select("p").first(),
              let text = try? paragraph.text(),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        // If the title selector is something like `p` we'd collide.
        if titleSelector == "p" { return nil }
        return "p"
    }
}
