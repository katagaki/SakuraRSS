import Foundation
import SwiftSoup

public extension HTMLContentExtractor {

    /// Picks the best available source URL from an image-like element:
    /// `<img>`, `<amp-img>`, or `<picture>`.  Prefers `srcset` descriptors
    /// when present, then falls back through common lazy-loading attributes,
    /// then the plain `src` attribute.  Returns `nil` when nothing usable
    /// was found.
    static func bestImageURL(from element: Element) -> String? {
        if element.tagName().lowercased() == "picture" {
            return pictureBestImageURL(from: element)
        }
        var dataURICandidate: String?
        for candidate in imageURLCandidates(from: element) {
            if candidate.hasPrefix("data:") {
                if dataURICandidate == nil { dataURICandidate = candidate }
                continue
            }
            return candidate
        }
        return dataURICandidate
    }

    private static let lazyImageAttributes = [
        "data-srcset", "data-src", "data-lazy-src", "data-original",
        "data-hi-res-src", "data-orig-file", "data-full-src",
        "data-original-src", "data-img-url"
    ]

    private static func imageURLCandidates(from element: Element) -> [String] {
        var candidates: [String] = []
        candidates.append(contentsOf: srcsetCandidates(ofAttribute: "srcset", on: element))
        for attribute in lazyImageAttributes {
            if attribute.hasSuffix("srcset") {
                candidates.append(
                    contentsOf: srcsetCandidates(ofAttribute: attribute, on: element)
                )
                continue
            }
            guard let raw = try? element.attr(attribute) else { continue }
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { candidates.append(value) }
        }
        if let sourceChild = try? element.select("source[srcset]").first() {
            candidates.append(
                contentsOf: srcsetCandidates(ofAttribute: "srcset", on: sourceChild)
            )
        }
        if let raw = try? element.attr("src") {
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { candidates.append(value) }
        }
        return candidates
    }

    private static func srcsetCandidates(
        ofAttribute attribute: String,
        on element: Element
    ) -> [String] {
        guard let raw = try? element.attr(attribute), !raw.isEmpty else { return [] }
        return srcsetCandidatesByPreference(raw)
    }

    private static func pictureBestImageURL(from element: Element) -> String? {
        if let sources = try? element.select("source") {
            for source in sources {
                if let srcset = try? source.attr("srcset"),
                   let best = largestSrcsetCandidate(srcset) {
                    return best
                }
            }
        }
        if let image = try? element.select("img, amp-img").first(),
           let candidate = bestImageURL(from: image) {
            return candidate
        }
        return nil
    }

    /// Parses a `srcset` value and returns the URL of the largest candidate.
    static func largestSrcsetCandidate(_ srcset: String) -> String? {
        srcsetCandidatesByPreference(srcset).first
    }

    /// Returns every `srcset` URL ordered from largest to smallest candidate,
    /// keeping source order for equal descriptors.
    static func srcsetCandidatesByPreference(_ srcset: String) -> [String] {
        parseSrcset(srcset)
            .enumerated()
            .sorted { first, second in
                if first.element.score == second.element.score {
                    return first.offset < second.offset
                }
                return first.element.score > second.element.score
            }
            .map { $0.element.url }
    }

    /// Follows the HTML srcset parsing rules: a candidate URL is an unbroken
    /// run of non-whitespace characters, so commas inside a URL (Cloudinary
    /// transforms, `data:` payloads) are not treated as separators.
    private static func parseSrcset(_ srcset: String) -> [(url: String, score: Double)] {
        var candidates: [(url: String, score: Double)] = []
        var index = srcset.startIndex
        let end = srcset.endIndex
        while index < end {
            while index < end, srcset[index].isWhitespace || srcset[index] == "," {
                index = srcset.index(after: index)
            }
            guard index < end else { break }
            let urlStart = index
            while index < end, !srcset[index].isWhitespace {
                index = srcset.index(after: index)
            }
            var url = String(srcset[urlStart..<index])
            if url.hasSuffix(",") {
                while url.hasSuffix(",") { url.removeLast() }
                if !url.isEmpty { candidates.append((url, 1)) }
                continue
            }
            while index < end, srcset[index].isWhitespace {
                index = srcset.index(after: index)
            }
            let descriptorStart = index
            while index < end, srcset[index] != "," {
                index = srcset.index(after: index)
            }
            let descriptor = String(srcset[descriptorStart..<index])
            if index < end { index = srcset.index(after: index) }
            candidates.append((url, srcsetDescriptorScore(descriptor)))
        }
        return candidates
    }

    private static func srcsetDescriptorScore(_ descriptor: String) -> Double {
        let normalized = descriptor
            .lowercased()
            .components(separatedBy: .whitespaces)
            .first { !$0.isEmpty } ?? ""
        if normalized.hasSuffix("w"), let value = Double(normalized.dropLast()) {
            return value
        }
        if normalized.hasSuffix("x"), let value = Double(normalized.dropLast()) {
            return value * 1000
        }
        return 1
    }
}
