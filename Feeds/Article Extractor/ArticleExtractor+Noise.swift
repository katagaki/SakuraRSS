import Foundation
import SwiftSoup

extension ArticleExtractor {

    static let noiseSelectors = [
        // Navigation & menus
        "nav",
        "header",
        "footer",
        "aside",
        ".sidebar",
        ".navigation",
        ".nav",
        ".navbar",
        ".menu",
        ".main-menu",
        ".site-menu",
        ".mobile-menu",
        ".dropdown-menu",
        ".breadcrumb",
        ".breadcrumbs",
        ".site-header",
        ".site-footer",
        ".page-header",
        ".page-footer",
        ".top-bar",
        ".bottom-bar",
        ".header-nav",
        ".footer-nav",
        ".skip-link",
        // Social & sharing
        ".social-share",
        ".social-shares",
        ".social-sharing",
        ".social-bar",
        ".social-buttons",
        ".social-nav",
        ".social-media",
        ".social-follow",
        ".share-buttons",
        ".share-button",
        ".share-bar",
        ".share-links",
        ".share-widget",
        ".share-tools",
        ".share-container",
        ".share-this",
        ".sharing",
        ".sharing-buttons",
        ".sharedaddy",
        ".jp-sharing",
        ".jp-relatedposts",
        ".sd-sharing",
        ".sd-social",
        ".addtoany",
        ".a2a_kit",
        ".addthis",
        ".addthis_toolbox",
        ".addthis_inline_share_toolbox",
        ".at-share-tbx-element",
        ".st-sharethis",
        ".sharethis-inline-share-buttons",
        ".social-links",
        ".social-icons",
        ".social-list",
        ".follow-us",
        ".follow-buttons",
        ".post-share",
        ".entry-share",
        ".article-share",
        ".article__share",
        ".author-social",
        ".share-post",
        ".tweet-this",
        ".twitter-share",
        ".facebook-share",
        ".linkedin-share",
        ".pinterest-share",
        ".reddit-share",
        ".whatsapp-share",
        // Embedded social widgets
        // (`.twitter-tweet` and `.twitter-timeline` intentionally NOT
        // listed - they are promoted to inline embeds before this runs.)
        ".fb-post",
        ".fb-like",
        ".fb-share-button",
        ".instagram-media",
        ".tiktok-embed",
        ".threads-embed",
        // Related content & suggestions
        ".related-posts",
        ".related-articles",
        ".related-content",
        ".related-stories",
        ".recommended",
        ".recommendations",
        ".suggested",
        ".suggested-posts",
        ".suggested-articles",
        ".more-stories",
        ".more-articles",
        ".more-from",
        ".read-next",
        ".read-more",
        ".up-next",
        ".also-read",
        ".trending",
        ".trending-posts",
        ".popular-posts",
        ".most-read",
        ".most-popular",
        ".top-stories",
        ".you-may-like",
        ".dont-miss",
        ".latest-posts",
        ".latest-articles",
        ".latest-stories",
        ".more-on",
        ".further-reading",
        // Comments
        ".comments",
        ".comment-section",
        ".comment-form",
        ".comment-list",
        ".comments-area",
        ".comments-section",
        ".disqus_thread",
        "#disqus_thread",
        "#comments",
        ".respond",
        ".comment-respond",
        ".discussion",
        // Ads
        ".advertisement",
        ".advert",
        ".adverts",
        ".ad-container",
        ".ad",
        ".ads",
        ".ad-slot",
        ".ad-wrapper",
        ".ad-wrap",
        ".ad-banner",
        ".ad-unit",
        ".ad-block",
        ".ad-box",
        ".ad-label",
        ".ad-placeholder",
        ".ad-space",
        ".ad-zone",
        ".ad-tag",
        ".ad-area",
        ".ad-region",
        ".ad-holder",
        ".ad-leaderboard",
        ".ad-sidebar",
        ".ad-inline",
        ".inline-ad",
        ".inline-ads",
        ".inline-advertisement",
        ".article-ad",
        ".post-ad",
        ".text-ad",
        ".banner-ad",
        ".google-ad",
        ".googlead",
        ".adsense",
        ".adsbygoogle",
        ".dfp-ad",
        ".gpt-ad",
        ".gpt-ad-slot",
        ".amp-ad",
        ".amp_ad",
        ".outbrain",
        ".OUTBRAIN",
        ".ob-widget",
        ".taboola",
        ".trc_rbox",
        ".taboola-placeholder",
        ".mgid",
        ".mgbox",
        ".revcontent",
        ".nativo",
        ".zergnet",
        ".sponsored",
        ".sponsored-content",
        ".sponsored-post",
        ".sponsored-by",
        ".sponsor-message",
        ".sponsorship",
        ".partner-content",
        ".paid-content",
        ".paid-post",
        ".promoted",
        ".promoted-content",
        ".promoted-stories",
        ".promo",
        ".promo-banner",
        ".promo-box",
        ".dianomi",
        "[id^=google_ads]",
        "[id^=div-gpt-ad]",
        "[id^=ad-]",
        "[id^=dfp-]",
        "[class*=advertisement]",
        "[data-ad]",
        "[data-ad-slot]",
        "[data-ad-unit]",
        "[data-google-query-id]",
        "[aria-label*=advertisement]",
        "[aria-label*=Advertisement]",
        "[aria-label*=sponsored]",
        "[aria-label*=Sponsored]",
        // NYTimes
        ".ad-text",
        ".ad-header",
        "[data-testid=StandardAd]",
        "[data-testid=CompanionAd]",
        "[data-testid=inline-message]",
        // Affiliate / FTC disclosures
        ".ad-disclaimer",
        ".ad-disclaimer-container",
        ".disclaimer-affiliate",
        ".affiliate-disclaimer",
        ".affiliate-disclosure",
        ".ftc-disclosure",
        ".ftc-disclaimer",
        ".disclosure",
        ".disclosure-notice",
        "#after_disclaimer_placement",
        ".visitor-promo",
        // Google nosnippet: content marked as non-article by publisher
        "[data-nosnippet]",
        "[data-nosnippet=true]",
        // Banners & popups
        ".cookie-banner",
        ".cookie-notice",
        ".cookie-consent",
        ".popup",
        ".modal",
        ".overlay",
        ".alert-banner",
        ".notification-bar",
        ".announcement-bar",
        ".paywall",
        ".paywall-prompt",
        ".gate",
        ".login-prompt",
        ".register-prompt",
        // Newsletter, signup & app-install CTAs
        ".newsletter",
        ".newsletter-signup",
        ".newsletter-form",
        ".newsletter-block",
        ".newsletter-widget",
        ".newsletters-widget",
        ".subscribe",
        ".subscribe-form",
        ".subscribe-box",
        ".subscribe-widget",
        ".subscription",
        ".subscription-block",
        ".subscription-box",
        ".subscription-newspick",
        ".signup",
        ".sign-up",
        ".email-signup",
        ".email-capture",
        ".mc-embed-signup",
        ".cta",
        ".call-to-action",
        ".get-app",
        ".get-the-app",
        ".app-download",
        ".app-install",
        ".app-promo",
        ".app-banner",
        ".app-cta",
        ".app-widget",
        ".download-app",
        ".install-app",
        ".smart-banner",
        ".mobile-app-banner",
        ".mobile-app-promo",
        ".whatsapp-group",
        ".whatsapp-signup",
        ".telegram-signup",
        ".join-channel",
        // Gift article / paywall upsell blocks
        ".gift-article",
        ".gift-article-button",
        ".gift-post",
        ".gift-link",
        ".gift-this-article",
        ".share-gift",
        // YouTube / channel promo blocks
        ".article__youtube-video",
        ".youtube-video__content",
        ".youtube-promo",
        ".youtube-cta",
        ".youtube-subscribe",
        ".subscribe-youtube",
        ".follow-us-youtube",
        ".channel-promo",
        ".block-type--subscription_cta_block",
        "[widget-type*=widget]",
        "[data-widget-type]",
        "[data-block-type*=cta]",
        "[data-block-type*=subscription]",
        "[data-block-type*=newsletter]",
        // UI elements
        ".toolbar",
        ".toolbars",
        ".action-bar",
        ".action-buttons",
        ".button-bar",
        ".button-group",
        ".button-row",
        ".icon-bar",
        ".icon-row",
        ".iconbar",
        ".iconlist",
        ".meta-bar",
        ".story-tools",
        ".article-tools",
        ".story-header-tools",
        ".utility-bar",
        ".utility-nav",
        ".floating-bar",
        ".floating-share",
        ".sticky-share",
        ".sticky-social",
        ".sticky-tools",
        ".social-toolbar",
        ".share-toolbar",
        ".post-toolbar",
        ".article-toolbar",
        ".article-actions",
        ".post-actions",
        ".entry-actions",
        ".article-footer-actions",
        ".pagination",
        ".pager",
        ".tags",
        ".tag-list",
        ".tag-cloud",
        ".category-links",
        ".post-categories",
        ".post-tags",
        ".entry-tags",
        ".entry-categories",
        ".toc",
        ".table-of-contents",
        ".print-only",
        ".screen-reader-text",
        ".visually-hidden",
        ".sr-only",
        ".a11y-hidden",
        // Author, byline & meta sections
        // (bare ".author" / ".authors" omitted - many themes use them on
        // inline <span> elements within article text; the class-pattern
        // sweep still catches wrapper divs via "author" substrings below.)
        ".author-bio",
        ".author-box",
        ".author-boxes",
        ".author-card",
        ".author-cards",
        ".author-block",
        ".author-info",
        ".author-details",
        ".author-profile",
        ".author-meta",
        ".author-section",
        ".author-footer",
        ".author-header",
        ".author-avatar",
        ".author-image",
        ".author-photo",
        ".author-name",
        ".author-byline",
        ".author-list",
        ".author-link",
        ".author-description",
        ".author-contact",
        ".post-author",
        ".post-authors",
        ".post-author-bio",
        ".post-author-box",
        ".post-author-card",
        ".post-byline",
        ".post-meta",
        ".post-meta__author",
        ".entry-author",
        ".entry-meta",
        ".entry-byline",
        ".article-author",
        ".article-authors",
        ".article-byline",
        ".article-meta",
        ".article__author",
        ".article__byline",
        ".article__meta",
        ".byline",
        ".byline-section",
        ".byline-wrapper",
        ".byline-container",
        ".bylines",
        ".bio",
        ".biography",
        ".about-author",
        ".about-the-author",
        ".contributor",
        ".contributor-card",
        ".contributors",
        ".written-by",
        ".meta-author",
        ".story-byline",
        ".story-author",
        ".news-author",
        // WordPress Gutenberg author blocks
        ".wp-block-tc23-author-card",
        "[class*=wp-block][class*=author-card]",
        "[class*=wp-block][class*=author-bio]",
        "[class*=wp-block-post-author]",
        "[class*=wp-block-co-authors]",
        "[class*=coauthors]",
        ".co-authors",
        ".coauthor",
        ".coauthors-wrap",
        // Schema.org author itemprop on standalone elements
        "[itemprop=author][itemscope]",
        "[itemprop=creator][itemscope]",
        "[rel=author]",
        // Publication date / timestamp metadata on standalone elements
        ".published-date",
        ".publish-date",
        ".publication-date",
        ".post-date",
        ".entry-date",
        ".article-date",
        ".date-published",
        ".timestamp",
        ".time-stamp",
        ".updated-date",
        ".last-updated",
        ".dateline-block",
        // ARIA roles
        "[role=navigation]",
        "[role=banner]",
        "[role=complementary]",
        "[role=contentinfo]",
        "[aria-label*=menu]",
        "[aria-label*=Menu]",
        "[aria-label*=navigation]",
        "[aria-label*=Navigation]",
        "[aria-label*=comment]",
        "[aria-label*=Comment]",
        "[aria-label*=related]",
        "[aria-label*=Related]",
        "[aria-label*=share]",
        "[aria-label*=Share]",
        "[aria-label*=advertisement]",
        "[aria-label*=Advertisement]",
        // Non-content elements
        "script",
        "style",
        "noscript",
        "iframe",
        "form",
        "button",
        "select",
        "input",
        "svg",
        "canvas",
        "template"
    ]

    /// Class/ID substrings that strongly indicate non-article content.
    private static let noiseClassPatterns = [
        "related", "recommend", "suggested", "popular",
        "trending", "sidebar", "widget", "promo",
        "newsletter", "subscribe", "subscription",
        "signup", "sign-up", "comment", "disqus",
        "social-share", "social-shares", "social-bar",
        "social-buttons", "social-media", "social-follow",
        "share-bar", "share-buttons", "share-tools",
        "share-this", "post-share", "entry-share",
        "article-share", "sharedaddy", "addtoany",
        "addthis", "sharethis",
        "ad-slot", "ad-wrap", "ad-unit", "ad-container",
        "ad-banner", "ad-block", "ad-box", "ad-label",
        "ad-leaderboard", "ad-sidebar", "ad-inline",
        "inline-ad", "article-ad", "banner-ad", "text-ad",
        "google-ad", "adsense", "adsbygoogle", "dfp-ad",
        "gpt-ad", "amp-ad", "outbrain", "taboola", "mgid",
        "revcontent", "nativo", "zergnet", "dianomi",
        "sponsored", "sponsor-message", "partner-content",
        "paid-content", "paid-post", "promoted",
        "footer-links", "site-footer", "more-stories",
        "also-like", "dont-miss",
        "read-next", "up-next", "most-read",
        // App-install / CTA widgets
        "get-app", "get-the-app", "app-download",
        "app-install", "app-promo", "app-banner",
        "app-cta", "app-widget", "download-app",
        "install-app", "smart-banner", "mobile-app-banner",
        "whatsapp-group", "whatsapp-signup", "telegram-signup",
        "subscription-cta", "subscription_cta",
        "gift-article", "gift-post", "gift-link",
        "gift-this-article", "share-gift",
        // Author cards, bylines & contributor blocks
        "author-bio", "author-box", "author-card",
        "author-block", "author-info", "author-details",
        "author-profile", "author-meta", "author-section",
        "author-footer", "author-header", "author-avatar",
        "author-byline", "post-author", "post-byline",
        "entry-author", "article-author", "article-byline",
        "byline", "contributor", "coauthor", "co-authors",
        "written-by", "about-author", "about-the-author",
        // WordPress Gutenberg author blocks
        "wp-block-tc23-author", "wp-block-post-author",
        "wp-block-co-authors",
        // Publication dates on dedicated blocks
        "published-date", "publish-date", "publication-date",
        "post-date", "entry-date", "article-date",
        "date-published", "last-updated",
        // Affiliate / FTC disclosures and channel promo
        "disclaimer-affiliate", "affiliate-disclaimer",
        "affiliate-disclosure", "ftc-disclosure",
        "ad-disclaimer", "after_disclaimer",
        "visitor-promo", "youtube-video",
        "youtube-promo", "youtube-cta", "youtube-subscribe",
        "channel-promo",
        "ad-text", "ad-header",
        // Toolbars, action bars, icon rows, tag/category footers
        "toolbar", "action-bar", "action-buttons",
        "button-bar", "button-group", "button-row",
        "icon-bar", "icon-row", "iconbar",
        "meta-bar", "story-tools", "article-tools",
        "utility-bar", "utility-nav", "floating-bar",
        "floating-share", "sticky-share", "sticky-social",
        "sticky-tools", "social-toolbar", "share-toolbar",
        "post-toolbar", "article-toolbar", "article-actions",
        "post-actions", "entry-actions", "tag-cloud",
        "post-categories", "post-tags",
        "entry-tags", "entry-categories", "category-links"
    ]

    /// Noise-removal modes.  The aggressive `.global` pass runs on the
    /// whole document and is free to strip broad selectors; `.local` runs
    /// on the already-selected main content element and refuses to drop
    /// selectors that might appear inside legitimate paragraphs.
    enum NoiseScope {
        case global
        case local
    }

    /// Class/ID substrings that would be too aggressive to remove once the
    /// article container has been isolated.  Matches the bare tokens that
    /// legitimate inline spans (`<span class="share">value</span>`) or
    /// image captions might use.
    private static let unsafeInsideArticle: Set<String> = [
        "share-bar", "share-buttons", "share-tools",
        "share-this", "post-share", "entry-share",
        "article-share", "sharedaddy", "addtoany",
        "addthis", "sharethis", "social-share",
        "social-shares", "social-bar", "social-buttons",
        "social-media", "social-follow",
        "newsletter", "subscribe", "subscription",
        "signup", "sign-up",
        "post-author", "post-byline", "entry-author",
        "article-author", "article-byline",
        "byline", "contributor", "coauthor", "co-authors",
        "written-by", "about-author", "about-the-author",
        "published-date", "publish-date", "publication-date",
        "post-date", "entry-date", "article-date",
        "date-published", "last-updated",
        "related", "recommend", "suggested", "popular",
        "trending", "more-stories", "also-like", "dont-miss",
        "read-next", "up-next", "most-read"
    ]

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
        // Heuristic passes (see ArticleExtractor+NoiseHeuristics.swift).
        // Aggressive list/section sweeps only run on the full document so
        // scoped removal doesn't nuke legitimate inline content inside the
        // already-isolated article body.
        if scope == .global {
            removeMenuLists(from: element)
            removeSuggestionSections(from: element)
        }
        removeIconToolbars(from: element)
        removeShareButtonClusters(from: element)
        removeEmptyContainers(from: element)
    }

    /// Removes elements whose class or id attribute contains known noise substrings.
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
            // Best-effort; failures are non-critical
        }
    }

    /// Returns true when the trimmed, lowercased text matches a known ad label.
    static func isAdvertisementText(_ text: String) -> Bool {
        AdvertisementTextFilter.isAdvertisementText(text)
    }

    /// Removes block-level elements (`<p>`, `<div>`, `<span>`) whose only
    /// text content is a known ad label such as "ADVERTISEMENT".
    private static func removeAdvertisementTextBlocks(from element: Element) {
        do {
            let candidates = try element.select("p, div, span")
            for element in candidates {
                let text = try element.text()
                guard isAdvertisementText(text) else { continue }
                // Only remove if the element has no meaningful children
                // (images, videos, etc.) - just the ad label text.
                let hasMedia = !(try element.select("img, video, picture, iframe")).isEmpty()
                if !hasMedia {
                    try element.remove()
                }
            }
        } catch {
            // Best-effort; failures are non-critical
        }
    }

}
