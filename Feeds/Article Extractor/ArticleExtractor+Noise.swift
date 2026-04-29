import Foundation
import SwiftSoup

extension ArticleExtractor {

    static let noiseSelectors: [String] = NoiseData.selectors

    private static let noiseClassPatterns: [String] = NoiseData.classPatterns

    /// `.global` strips broadly across the document; `.local` is conservative inside an already-selected article.
    enum NoiseScope {
        case global
        case local
    }

    private static let unsafeInsideArticle: Set<String> = NoiseData.unsafeInsideArticle

    static func removeNoise(from element: Element) {
        removeNoise(from: element, scope: .global)
    }

    static func removeNoise(from element: Element, scope: NoiseScope) {
        for selector in noiseSelectors {
            do {
                let elements = try element.select(selector)
                try elements.remove()
            } catch {
                continue
            }
        }

        removeNoiseByClassPatterns(from: element, scope: scope)
        removeAdvertisementTextBlocks(from: element)
        // Aggressive list/section sweeps only run on the full document to
        // avoid nuking legitimate inline content inside isolated articles.
        if scope == .global {
            removeMenuLists(from: element)
            removeSuggestionSections(from: element)
        }
        removeIconToolbars(from: element)
        removeShareButtonClusters(from: element)
        removeEmptyContainers(from: element)
    }

    private static func removeNoiseByClassPatterns(
        from element: Element,
        scope: NoiseScope = .global
    ) {
        do {
            let allElements = try element.select("div, section, aside, ul, ol")
            for element in allElements {
                let className = (try? element.attr("class"))?.lowercased() ?? ""
                let idName = (try? element.attr("id"))?.lowercased() ?? ""
                let combined = className + " " + idName
                for pattern in noiseClassPatterns where combined.contains(pattern) {
                    if scope == .local && unsafeInsideArticle.contains(pattern) {
                        continue
                    }
                    try element.remove()
                    break
                }
            }
        } catch {
        }
    }

    /// Returns true when the trimmed, lowercased text matches a known ad label.
    static func isAdvertisementText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return NoiseData.advertisementTextPatterns.contains(trimmed)
    }

    private static func removeAdvertisementTextBlocks(from element: Element) {
        do {
            let candidates = try element.select("p, div, span")
            for element in candidates {
                let text = try element.text()
                guard isAdvertisementText(text) else { continue }
                // Keep elements containing media; only strip pure-label blocks.
                let hasMedia = !(try element.select("img, video, picture, iframe")).isEmpty()
                if !hasMedia {
                    try element.remove()
                }
            }
        } catch {
        }
    }

}
