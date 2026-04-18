import Foundation
import SwiftSoup

extension ArticleExtractor {

    /// Pre-processes the document to convert supported social embeds
    /// (YouTube, X/Twitter) into plain-text marker paragraphs that survive
    /// noise removal and text extraction.  Must run *before* `removeNoise`
    /// because the noise selectors would otherwise strip twitter-tweet
    /// blockquotes and YouTube iframes entirely.
    static func promoteInlineEmbeds(in doc: Document, baseURL: URL? = nil) {
        promoteYouTubeEmbeds(in: doc)
        promoteXEmbeds(in: doc)
        promoteGenericEmbeds(in: doc)
    }

    // MARK: - YouTube

    private static func promoteYouTubeEmbeds(in element: Element) {
        // <iframe src=".../embed/VIDEO_ID"> - canonical YouTube embed
        if let iframes = try? element.select("iframe[src]") {
            for iframe in iframes {
                guard let src = try? iframe.attr("src"),
                      let videoID = youTubeVideoID(fromEmbedURL: src) else {
                    continue
                }
                replaceWithMarker(element: iframe,
                                  marker: "{{YOUTUBE}}\(videoID){{/YOUTUBE}}")
            }
        }

        // <lite-youtube videoid="..."> - lazy-loader custom element
        if let liteElements = try? element.select("lite-youtube[videoid]") {
            for lite in liteElements {
                guard let videoID = try? lite.attr("videoid"),
                      !videoID.isEmpty else { continue }
                replaceWithMarker(element: lite,
                                  marker: "{{YOUTUBE}}\(videoID){{/YOUTUBE}}")
            }
        }

        // <div data-youtube-id="..."> / <div data-video-id="..."> on
        // YouTube-hosted player shells
        if let ytShells = try? element.select(
            "div[data-youtube-id], div[data-youtube-video-id]"
        ) {
            for shell in ytShells {
                // SwiftSoup's `attr` returns "" for missing attributes, so
                // we can't use nil-coalescing to select the first non-empty
                // attribute value.
                var videoID = (try? shell.attr("data-youtube-id")) ?? ""
                if videoID.isEmpty {
                    videoID = (try? shell.attr("data-youtube-video-id")) ?? ""
                }
                guard !videoID.isEmpty else { continue }
                replaceWithMarker(element: shell,
                                  marker: "{{YOUTUBE}}\(videoID){{/YOUTUBE}}")
            }
        }

        // Bare <a href=".../watch?v=ID"> that's the sole content of a
        // paragraph (common in blog posts) - treat as an embed too.
        if let anchors = try? element.select("p > a[href], figure > a[href]") {
            for anchor in anchors {
                guard let parent = anchor.parent() else { continue }
                // Only one child, an anchor, with visible text == the href
                let siblingCount = parent.children().size()
                guard siblingCount == 1 else { continue }
                guard let href = try? anchor.attr("href"),
                      let videoID = youTubeVideoID(fromWatchURL: href) else {
                    continue
                }
                let text = (try? anchor.text()) ?? ""
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                // Only collapse if the visible link text is the URL itself.
                // Otherwise the link has meaningful anchor text and should stay.
                guard trimmed == href || trimmed.isEmpty else { continue }
                replaceWithMarker(element: parent,
                                  marker: "{{YOUTUBE}}\(videoID){{/YOUTUBE}}")
            }
        }
    }

    /// Extracts a YouTube video ID from an embed URL like
    /// `https://www.youtube.com/embed/VIDEO_ID?...` or
    /// `https://www.youtube-nocookie.com/embed/VIDEO_ID`.
    static func youTubeVideoID(fromEmbedURL src: String) -> String? {
        let lowered = src.lowercased()
        let isYT = lowered.contains("youtube.com/embed/")
            || lowered.contains("youtube-nocookie.com/embed/")
            || lowered.contains("youtube.com/shorts/")
        guard isYT, let url = URL(string: absoluteURLString(src)) else { return nil }
        let parts = url.path.split(separator: "/")
        guard let last = parts.last else { return nil }
        let id = String(last).trimmingCharacters(in: .whitespaces)
        return id.isEmpty ? nil : id
    }

    /// Extracts a YouTube video ID from a watch or short URL like
    /// `https://www.youtube.com/watch?v=ID` or `https://youtu.be/ID`.
    static func youTubeVideoID(fromWatchURL src: String) -> String? {
        guard let url = URL(string: absoluteURLString(src)),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let host = components.host?.lowercased() ?? ""
        if host.contains("youtube.com") {
            if components.path.hasPrefix("/shorts/") || components.path.hasPrefix("/embed/") {
                let parts = components.path.split(separator: "/")
                if parts.count >= 2 { return String(parts[1]) }
            }
            return components.queryItems?.first(where: { $0.name == "v" })?.value
        }
        if host.contains("youtu.be") {
            let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return path.isEmpty ? nil : path
        }
        return nil
    }

    // MARK: - X / Twitter

    private static func promoteXEmbeds(in element: Element) {
        // <blockquote class="twitter-tweet"> with a trailing <a href="…/status/ID">
        if let blockquotes = try? element.select("blockquote.twitter-tweet") {
            for blockquote in blockquotes {
                guard let anchor = xStatusAnchor(in: blockquote),
                      let href = try? anchor.attr("href"),
                      let normalized = normalizedXStatusURL(href) else {
                    continue
                }
                replaceWithMarker(element: blockquote,
                                  marker: "{{XPOST}}\(normalized){{/XPOST}}")
            }
        }

        // Twitter/X iframe embeds (platform.twitter.com/embed/Tweet.html?id=…)
        if let iframes = try? element.select("iframe[src]") {
            for iframe in iframes {
                guard let src = try? iframe.attr("src"),
                      let url = URL(string: absoluteURLString(src)),
                      let host = url.host?.lowercased(),
                      host.contains("platform.twitter.com")
                        || host.contains("platform.x.com")
                        || host.contains("publish.twitter.com")
                        || host.contains("publish.x.com") else {
                    continue
                }
                if let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "id" })?.value,
                   !id.isEmpty,
                   let normalized = normalizedXStatusURL("https://x.com/i/status/\(id)") {
                    replaceWithMarker(element: iframe,
                                      marker: "{{XPOST}}\(normalized){{/XPOST}}")
                }
            }
        }

        // Bare <a href="https://x.com/user/status/ID"> that's the sole child
        // of a paragraph - promote to inline embed.
        if let anchors = try? element.select("p > a[href], figure > a[href]") {
            for anchor in anchors {
                guard let parent = anchor.parent() else { continue }
                let siblingCount = parent.children().size()
                guard siblingCount == 1 else { continue }
                guard let href = try? anchor.attr("href"),
                      let normalized = normalizedXStatusURL(href) else {
                    continue
                }
                let text = (try? anchor.text()) ?? ""
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed == href || trimmed.isEmpty else { continue }
                replaceWithMarker(element: parent,
                                  marker: "{{XPOST}}\(normalized){{/XPOST}}")
            }
        }
    }

    private static func xStatusAnchor(in blockquote: Element) -> Element? {
        guard let anchors = try? blockquote.select("a[href]") else { return nil }
        for anchor in anchors {
            let href = (try? anchor.attr("href")) ?? ""
            if normalizedXStatusURL(href) != nil { return anchor }
        }
        return nil
    }

    /// Returns a canonicalized x.com status URL string, or nil if the input
    /// isn't a recognizable X/Twitter status URL.
    static func normalizedXStatusURL(_ src: String) -> String? {
        guard let url = URL(string: absoluteURLString(src)),
              let host = url.host?.lowercased() else {
            return nil
        }
        let isXHost = host == "x.com" || host.hasSuffix(".x.com")
            || host == "twitter.com" || host.hasSuffix(".twitter.com")
            || host == "mobile.twitter.com" || host == "mobile.x.com"
        guard isXHost else { return nil }
        // Expect /user/status/ID or /i/status/ID (or /i/web/status/ID)
        let parts = url.path.split(separator: "/").map(String.init)
        guard let statusIndex = parts.firstIndex(of: "status"),
              statusIndex + 1 < parts.count else {
            return nil
        }
        let id = parts[statusIndex + 1]
            .trimmingCharacters(in: CharacterSet(charactersIn: "?#"))
        guard !id.isEmpty, id.allSatisfy(\.isNumber) else { return nil }
        let user: String
        if statusIndex > 0 {
            let candidate = parts[statusIndex - 1]
            user = (candidate == "i" || candidate == "web") ? "i" : candidate
        } else {
            user = "i"
        }
        return "https://x.com/\(user)/status/\(id)"
    }

    // MARK: - Marker detection

    /// Returns the sole embed marker (`{{YOUTUBE}}…{{/YOUTUBE}}` or
    /// `{{XPOST}}…{{/XPOST}}`) if `text` contains only a single marker
    /// and nothing else (ignoring surrounding whitespace).
    static func embedMarkerParagraph(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let patterns = [
            #"^\{\{YOUTUBE\}\}[A-Za-z0-9_\-]+\{\{/YOUTUBE\}\}$"#,
            #"^\{\{XPOST\}\}https?://[^\s]+\{\{/XPOST\}\}$"#,
            #"^\{\{EMBED\}\}[a-z]+\|[^\s]+\{\{/EMBED\}\}$"#
        ]
        for pattern in patterns {
            if trimmed.range(of: pattern, options: .regularExpression) != nil {
                return trimmed
            }
        }
        return nil
    }

    // MARK: - Helpers

    /// Ensures a URL string has a scheme.  Protocol-relative URLs (`//…`)
    /// are resolved to `https:` so downstream parsing sees an absolute host.
    private static func absoluteURLString(_ src: String) -> String {
        if src.hasPrefix("//") { return "https:\(src)" }
        return src
    }

    /// Replaces a DOM element with a `<p>` containing only a marker string.
    /// Using `<p>` keeps the marker isolated as its own paragraph during
    /// block collection, preventing surrounding text from merging in.
    /// Walks up through common embed wrappers (`<figure>`, `<div>` etc.)
    /// when the wrapper has no other meaningful content, so the marker
    /// surfaces at the article-body level.
    private static func replaceWithMarker(element: Element, marker: String) {
        let target = outermostEmbedWrapper(for: element)
        do {
            try target.before("<p>\(marker)</p>")
            try target.remove()
        } catch {
            // Best-effort: a failed promotion leaves the original element,
            // which noise removal will likely strip anyway.
        }
    }

    /// Walks up through wrapper elements (`<figure>`, `<div>`, `<aside>`,
    /// `<p>`) that contain *only* the embed element (ignoring whitespace).
    /// Stops as soon as the parent has other content.
    private static func outermostEmbedWrapper(for element: Element) -> Element {
        let wrapperTags: Set<String> = ["figure", "div", "aside", "p", "span"]
        var current: Element = element
        while let parent = current.parent(), wrapperTags.contains(parent.tagName().lowercased()) {
            // Only hoist when current is the parent's sole significant child.
            let siblings = parent.children().filter { $0 !== current }
            let siblingHasText = siblings.contains { element in
                let text = ((try? element.text()) ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return !text.isEmpty
            }
            if siblingHasText { break }
            // Also check for raw text nodes on the parent.
            let ownText = ((try? parent.ownText()) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !ownText.isEmpty { break }
            current = parent
        }
        return current
    }
}
