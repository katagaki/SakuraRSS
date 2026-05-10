import Foundation
import SwiftSoup

/// Heuristic selector inference for Web Feed recipes, used by the builder's Auto-Detect.
nonisolated enum PetalAutoDetect {

    static func detect(html: String, siteURL: String) -> PetalRecipe? {
        guard let document = try? SwiftSoup.parse(html, siteURL) else {
            return nil
        }

        guard let itemSelector = findItemSelector(in: document) else {
            return nil
        }
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

    private static func findItemSelector(in document: Document) -> String? {
        guard let links = try? document.select("a[href]") else {
            return nil
        }

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
            if matched.count > 60 && !candidate.key.contains(".") {
                continue
            }
            return candidate.key
        }
        return nil
    }

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
        guard let anchors = try? item.select("a[href]"), anchors.count > 1 else {
            return nil
        }
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
        guard let paragraph = try? item.select("p").first(),
              let text = try? paragraph.text(),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        if titleSelector == "p" { return nil }
        return "p"
    }
}
