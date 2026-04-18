import Foundation
import SwiftSoup

extension ArticleExtractor {

    /// Promotes Vimeo, TikTok, Instagram, Bluesky, Spotify, SoundCloud,
    /// CodePen, and GitHub Gist embeds to `{{EMBED}}provider|url{{/EMBED}}`
    /// marker paragraphs so noise removal doesn't strip them as iframes.
    static func promoteGenericEmbeds(in doc: Document) {
        promoteIframeEmbeds(in: doc)
        promoteTikTokBlockquotes(in: doc)
        promoteInstagramBlockquotes(in: doc)
        promoteBlueskyEmbeds(in: doc)
        promoteGistScripts(in: doc)
        promoteAnchorEmbeds(in: doc)
    }

    // MARK: - Iframes

    private static func promoteIframeEmbeds(in doc: Document) {
        guard let iframes = try? doc.select("iframe[src]") else { return }
        for iframe in iframes {
            guard let src = try? iframe.attr("src"),
                  let resolved = absoluteEmbedURL(src),
                  let provider = providerForEmbedURL(resolved) else {
                continue
            }
            insertEmbedMarker(replacing: iframe,
                              provider: provider,
                              url: resolved)
        }
    }

    // MARK: - Blockquote-based

    private static func promoteTikTokBlockquotes(in doc: Document) {
        guard let blocks = try? doc.select("blockquote.tiktok-embed") else {
            return
        }
        for block in blocks {
            let cite = (try? block.attr("cite")) ?? ""
            let url: String
            if !cite.isEmpty {
                url = cite
            } else {
                let videoID = (try? block.attr("data-video-id")) ?? ""
                guard !videoID.isEmpty else { continue }
                url = "https://www.tiktok.com/embed/v2/\(videoID)"
            }
            insertEmbedMarker(replacing: block,
                              provider: .tiktok,
                              url: url)
        }
    }

    private static func promoteInstagramBlockquotes(in doc: Document) {
        guard let blocks = try? doc.select("blockquote.instagram-media") else {
            return
        }
        for block in blocks {
            let permalink = (try? block.attr("data-instgrm-permalink")) ?? ""
            if permalink.isEmpty { continue }
            let clean = permalink.components(separatedBy: "?").first ?? permalink
            insertEmbedMarker(replacing: block,
                              provider: .instagram,
                              url: clean)
        }
    }

    private static func promoteBlueskyEmbeds(in doc: Document) {
        guard let blocks = try? doc.select(
            "blockquote.bluesky-embed, div.bluesky-embed"
        ) else { return }
        for block in blocks {
            let permalink = (try? block.attr("data-bluesky-uri")) ?? ""
            let href: String
            if let anchor = try? block.select("a[href]").first(),
               let anchorHref = try? anchor.attr("href"),
               anchorHref.contains("bsky.app") {
                href = anchorHref
            } else if !permalink.isEmpty {
                href = permalink
            } else {
                continue
            }
            insertEmbedMarker(replacing: block,
                              provider: .bluesky,
                              url: href)
        }
    }

    private static func promoteGistScripts(in doc: Document) {
        guard let scripts = try? doc.select("script[src]") else { return }
        for script in scripts {
            guard let src = try? script.attr("src"),
                  src.contains("gist.github.com"),
                  src.hasSuffix(".js"),
                  let resolved = absoluteEmbedURL(src) else {
                continue
            }
            let htmlURL = resolved.replacingOccurrences(of: ".js", with: "")
            insertEmbedMarker(replacing: script,
                              provider: .gist,
                              url: htmlURL)
        }
    }

    // MARK: - Anchor-only (bare link in its own paragraph)

    private static func promoteAnchorEmbeds(in doc: Document) {
        guard let anchors = try? doc.select("p > a[href], figure > a[href]") else {
            return
        }
        for anchor in anchors {
            guard let parent = anchor.parent(),
                  parent.children().size() == 1,
                  let href = try? anchor.attr("href"),
                  let resolved = absoluteEmbedURL(href),
                  let provider = providerForAnchorURL(resolved) else {
                continue
            }
            let text = ((try? anchor.text()) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.isEmpty || text == href || text == resolved else {
                continue
            }
            insertEmbedMarker(replacing: parent,
                              provider: provider,
                              url: resolved)
        }
    }

    // MARK: - Provider detection

    private static let vimeoEmbedPattern = "player.vimeo.com/video/"
    private static let vimeoAnchorPattern = "vimeo.com/"
    private static let vimeoPlayerHost = "player.vimeo.com"
    private static let tiktokEmbedPattern = "tiktok.com/embed"
    private static let tiktokHostPattern = "tiktok.com/"
    private static let tiktokVideoPathPattern = "/video/"
    private static let instagramPostPattern = "instagram.com/p/"
    private static let instagramReelPattern = "instagram.com/reel/"
    private static let blueskyHost = "bsky.app"
    private static let blueskyProfilePattern = "bsky.app/profile/"
    private static let blueskyPostPathPattern = "/post/"
    private static let spotifyEmbedPattern = "open.spotify.com/embed"
    private static let spotifyHostPattern = "open.spotify.com/"
    private static let soundcloudEmbedPattern = "w.soundcloud.com/player/"
    private static let soundcloudHostPattern = "soundcloud.com/"
    private static let codepenHostPattern = "codepen.io"
    private static let codepenEmbedPathPattern = "/embed/"

    static func providerForEmbedURL(_ src: String) -> EmbedProvider? {
        let lowered = src.lowercased()
        if lowered.contains(vimeoEmbedPattern) { return .vimeo }
        if lowered.contains(tiktokEmbedPattern) { return .tiktok }
        if lowered.contains(instagramPostPattern) || lowered.contains(instagramReelPattern) {
            return .instagram
        }
        if lowered.contains(blueskyHost) { return .bluesky }
        if lowered.contains(spotifyEmbedPattern) { return .spotify }
        if lowered.contains(soundcloudEmbedPattern) { return .soundcloud }
        if lowered.contains(codepenHostPattern) && lowered.contains(codepenEmbedPathPattern) {
            return .codepen
        }
        return nil
    }

    private static func providerForAnchorURL(_ src: String) -> EmbedProvider? {
        let lowered = src.lowercased()
        if lowered.contains(vimeoAnchorPattern) && !lowered.contains(vimeoPlayerHost) {
            return .vimeo
        }
        if lowered.contains(tiktokHostPattern) && lowered.contains(tiktokVideoPathPattern) {
            return .tiktok
        }
        if lowered.contains(spotifyHostPattern) { return .spotify }
        if lowered.contains(soundcloudHostPattern) { return .soundcloud }
        if lowered.contains(blueskyProfilePattern) && lowered.contains(blueskyPostPathPattern) {
            return .bluesky
        }
        return nil
    }

    // MARK: - Helpers

    private static func absoluteEmbedURL(_ src: String) -> String? {
        if src.hasPrefix("http://") || src.hasPrefix("https://") { return src }
        if src.hasPrefix("//") { return "https:\(src)" }
        return nil
    }

    private static func insertEmbedMarker(
        replacing element: Element,
        provider: EmbedProvider,
        url: String
    ) {
        let encoded = url
            .replacingOccurrences(of: "|", with: "%7C")
        let marker = "{{EMBED}}\(provider.rawValue)|\(encoded){{/EMBED}}"
        let target = outermostSimpleWrapper(for: element)
        do {
            try target.before("<p>\(marker)</p>")
            try target.remove()
        } catch {
            // Best-effort
        }
    }

    private static func outermostSimpleWrapper(for element: Element) -> Element {
        let wrapperTags: Set<String> = ["figure", "div", "aside", "p", "span"]
        var current = element
        while let parent = current.parent(),
              wrapperTags.contains(parent.tagName().lowercased()) {
            let siblings = parent.children().filter { $0 !== current }
            let siblingHasText = siblings.contains { sibling in
                let text = ((try? sibling.text()) ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return !text.isEmpty
            }
            if siblingHasText { break }
            let ownText = parent.ownText()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !ownText.isEmpty { break }
            current = parent
        }
        return current
    }
}
