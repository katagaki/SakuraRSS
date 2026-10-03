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
                let names = normalizedClassNames(of: candidate)
                for pattern in noiseClassPatterns where names.contains(where: {
                    classNameContainsNoisePattern($0, pattern: pattern)
                }) {
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

    private static let noisePatternSuffixes = ["", "s", "es", "ed", "ing", "ation", "ations"]

    /// Class and id names lowercased, with camelCase and underscores turned into hyphens.
    private static func normalizedClassNames(of element: Element) -> [String] {
        let rawNames = ((try? element.attr("class")) ?? "") + " " + ((try? element.attr("id")) ?? "")
        return rawNames.split(whereSeparator: \.isWhitespace).map { rawName in
            var normalized = ""
            var previous: Character?
            for character in rawName {
                if character.isUppercase, let previous, previous.isLowercase {
                    normalized.append("-")
                }
                normalized.append(character == "_" ? "-" : character)
                previous = character
            }
            return normalized.lowercased()
        }
    }

    /// Matches whole hyphen-separated segments so "comment" hits `comments-area`
    /// but not `commentary`, and "related" doesn't hit `unrelated`.
    private static func classNameContainsNoisePattern(_ name: String, pattern: String) -> Bool {
        let normalizedPattern = pattern.replacingOccurrences(of: "_", with: "-")
        var searchStart = name.startIndex
        while let range = name.range(of: normalizedPattern, range: searchStart..<name.endIndex) {
            let startsSegment = range.lowerBound == name.startIndex
                || name[name.index(before: range.lowerBound)] == "-"
            let segmentEnd = name[range.upperBound...].firstIndex(of: "-") ?? name.endIndex
            let suffix = String(name[range.upperBound..<segmentEnd])
            if startsSegment && noisePatternSuffixes.contains(suffix) {
                return true
            }
            searchStart = name.index(after: range.lowerBound)
        }
        return false
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
