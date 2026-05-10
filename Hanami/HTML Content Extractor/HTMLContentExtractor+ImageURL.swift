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
        if let lazy = lazyAttributeImageURL(from: element) {
            return lazy
        }
        return fallbackSrcsetImageURL(from: element)
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
        if let img = try? element.select("img, amp-img").first(),
           let candidate = bestImageURL(from: img) {
            return candidate
        }
        return nil
    }

    private static func lazyAttributeImageURL(from element: Element) -> String? {
        let lazyAttrs = [
            "src", "data-src", "data-lazy-src", "data-original",
            "data-hi-res-src", "data-orig-file", "data-full-src",
            "data-original-src", "data-img-url", "data-srcset"
        ]
        for attr in lazyAttrs {
            guard let raw = try? element.attr(attr), !raw.isEmpty else { continue }
            if attr.hasSuffix("srcset") {
                if let best = largestSrcsetCandidate(raw) { return best }
            } else {
                return raw
            }
        }
        return nil
    }

    private static func fallbackSrcsetImageURL(from element: Element) -> String? {
        if let srcset = try? element.attr("srcset"),
           let best = largestSrcsetCandidate(srcset) {
            return best
        }
        if let sourceChild = try? element.select("source[srcset]").first(),
           let srcset = try? sourceChild.attr("srcset"),
           let best = largestSrcsetCandidate(srcset) {
            return best
        }
        return nil
    }

    /// Parses a `srcset` value and returns the URL of the largest candidate.
    /// Candidates take the form `URL[ width][w|x]` and are comma-separated.
    static func largestSrcsetCandidate(_ srcset: String) -> String? {
        let cleaned = srcset.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        let candidates = cleaned.components(separatedBy: ",")

        var best: (url: String, score: Double)?
        for candidate in candidates {
            let parts = candidate
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
            guard let url = parts.first else { continue }
            let score: Double
            if parts.count >= 2 {
                let descriptor = parts[1].lowercased()
                if descriptor.hasSuffix("w"),
                   let value = Double(descriptor.dropLast()) {
                    score = value
                } else if descriptor.hasSuffix("x"),
                          let value = Double(descriptor.dropLast()) {
                    score = value * 1000
                } else {
                    score = 1
                }
            } else {
                score = 1
            }
            if let current = best {
                if score > current.score {
                    best = (url, score)
                }
            } else {
                best = (url, score)
            }
        }
        return best?.url
    }
}
