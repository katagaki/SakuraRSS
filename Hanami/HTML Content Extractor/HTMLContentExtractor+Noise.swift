import Foundation
import SwiftSoup

public nonisolated extension HTMLContentExtractor {

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

        removeStandaloneTimeElements(from: element)
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
            let totalParagraphCharacters = paragraphCharacterCount(in: element)
            let allElements = try element.select("div, section, aside, ul, ol")
            for candidate in allElements {
                let className = (try? candidate.attr("class"))?.lowercased() ?? ""
                let idName = (try? candidate.attr("id"))?.lowercased() ?? ""
                let combined = className + " " + idName
                for pattern in noiseClassPatterns where combined.contains(pattern) {
                    if scope == .local && unsafeInsideArticle.contains(pattern) {
                        continue
                    }
                    if holdsMostParagraphText(candidate, of: totalParagraphCharacters) {
                        break
                    }
                    try candidate.remove()
                    break
                }
            }
        } catch {
        }
    }

    /// Datelines leak into the body as orphan lines; dates inside sentences are prose.
    private static func removeStandaloneTimeElements(from element: Element) {
        let timeElements = (try? element.select("time").array()) ?? []
        for timeElement in timeElements {
            guard let parent = timeElement.parent() else { continue }
            let timeText = ((try? timeElement.text()) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let parentText = ((try? parent.text()) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if timeText == parentText {
                try? timeElement.remove()
            }
        }
    }

    /// Layout wrappers can carry noise-like class names (Future plc's main
    /// column is `widget-area`), so never strip the bulk of the prose.
    private static func holdsMostParagraphText(_ element: Element, of total: Int) -> Bool {
        guard total >= 500 else { return false }
        return paragraphCharacterCount(in: element) * 2 > total
    }

    private static func paragraphCharacterCount(in element: Element) -> Int {
        let paragraphs = (try? element.select("p").array()) ?? []
        return paragraphs.reduce(0) { total, paragraph in
            total + ((try? paragraph.text().count) ?? 0)
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
