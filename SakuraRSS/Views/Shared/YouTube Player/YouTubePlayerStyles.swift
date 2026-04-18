import Foundation

nonisolated enum YouTubePlayerStyles {

    /// CSS injected into the YouTube watch page to hide the surrounding
    /// mobile-site chrome (top bar, metadata section, comments, related
    /// videos, subscribe buttons, etc.) and YouTube's own player controls,
    /// so that only the bare video player remains visible while our SwiftUI
    /// controls sit underneath.
    ///
    /// Crucially, nothing here touches the `<video>` element, `#movie_player`,
    /// `.html5-video-player`, `.html5-video-container`, or their ancestor
    /// containers — those must stay visible for the video to actually render.
    static let css = """
    html, body {
        margin: 0 !important;
        padding: 0 !important;
        background: #000 !important;
        overflow: hidden !important;
        width: 100% !important;
        height: 100% !important;
    }
    /* Strip default margins on the page wrappers and let them fill the
       web view, so the player isn't pushed in by YouTube's mobile gutters.
       The video element itself is left alone; only margin/width on its
       ancestors is normalized. Heights and paddings are left intact so the
       16:9 aspect-ratio padding YouTube uses to size the player still
       works. */
    ytm-app, ytm-mobile-watch-flexy, ytm-watch,
    ytm-single-column-watch-next-results-renderer,
    ytm-watch-flexy, ytm-watch-flexy-content,
    .player-placeholder, .player-container,
    .player-screen, .player-size,
    #movie_player, .html5-video-player {
        margin: 0 !important;
        width: 100% !important;
        max-width: none !important;
        min-width: 0 !important;
    }
    /* Mobile YouTube (m.youtube.com) chrome */
    ytm-mobile-topbar-renderer,
    ytm-masthead,
    .mobile-topbar-header,
    .mobile-topbar-header-content,
    header[role="banner"],
    ytm-pivot-bar-renderer,
    ytm-feed-filter-chip-bar-renderer,
    ytm-slim-video-information-renderer,
    ytm-slim-video-metadata-renderer,
    ytm-slim-video-metadata-section-renderer,
    ytm-slim-owner-renderer,
    ytm-video-actions-renderer,
    ytm-video-owner-renderer,
    ytm-watch-metadata,
    ytm-item-section-renderer,
    ytm-shelf-renderer,
    ytm-comments-entry-point-header-renderer,
    ytm-engagement-panel-section-list-renderer,
    ytm-companion-slot,
    ytm-compact-autoplay-renderer,
    ytm-reel-shelf-renderer,
    ytm-playlist-panel-renderer,
    ytm-video-with-context-renderer,
    .related-chips-slot-wrapper,
    .video-actions,
    #player-bottom-sheet,
    #masthead, #app-drawer, #chat, #comments,
    #related, #secondary,
    /* Desktop YouTube (youtube.com) chrome */
    ytd-masthead, ytd-mini-guide-renderer, ytd-watch-metadata,
    ytd-engagement-panel-section-list-renderer,
    ytd-merch-shelf-renderer, ytd-info-panel-content-renderer,
    ytd-compact-promoted-video-renderer, ytd-feed-filter-chip-bar-renderer,
    ytd-consent-bump-v2-lightbox, ytd-popup-container,
    .ytd-watch-next-secondary-results-renderer,
    #description, #actions, #above-the-fold, #below, #info, #meta,
    #masthead-container, #guide, #chips, #header,
    tp-yt-paper-dialog, tp-yt-app-drawer {
        display: none !important;
        visibility: hidden !important;
        height: 0 !important;
        opacity: 0 !important;
        pointer-events: none !important;
    }
    /* YouTube's own player chrome — we provide our own controls below the
       web view. The player itself and its video element are NOT touched. */
    .ytp-chrome-top, .ytp-chrome-bottom, .ytp-chrome-controls,
    .ytp-gradient-top, .ytp-gradient-bottom,
    .ytp-title, .ytp-title-text, .ytp-title-channel,
    .ytp-title-link, .ytp-title-expanded-heading,
    .ytp-overflow-button, .ytp-settings-button,
    .ytp-share-button, .ytp-watch-later-button,
    .ytp-left-controls, .ytp-right-controls,
    .ytp-progress-bar-container, .ytp-progress-bar,
    .ytp-scrubber-container, .ytp-time-display,
    .ytp-play-button, .ytp-pause-button,
    .ytp-next-button, .ytp-prev-button,
    .ytp-mute-button, .ytp-volume-panel, .ytp-volume-slider,
    .ytp-subtitles-button, .ytp-captions-button,
    .ytp-fullscreen-button, .ytp-size-button,
    .ytp-miniplayer-button, .ytp-pip-button,
    .ytp-large-play-button, .ytp-cued-thumbnail-overlay,
    .ytp-pause-overlay, .ytp-pause-overlay-container,
    .ytp-endscreen-content, .ytp-endscreen-element,
    .ytp-ce-element, .ytp-ce-covering-overlay,
    .ytp-ce-covering-image, .ytp-ce-element-shadow,
    .ytp-ce-video, .ytp-ce-playlist, .ytp-ce-channel,
    .ytp-cards-teaser, .ytp-cards-button, .ytp-cards-button-title,
    .ytp-paid-content-overlay, .ytp-watermark,
    .ytp-youtube-button, .iv-branding, .iv-click-target,
    .branding-img-container, .ytp-iv-video-content,
    .ytp-show-tiles, .ytp-replay-button, .ytp-share-panel,
    .ytp-copylink-button, .ytp-copylink,
    .ytp-fullerscreen-edu-button,
    .ytp-suggested-action, .ytp-suggested-action-badge-container,
    .ytp-suggested-action-badge-expanded,
    .ytp-tooltip, .ytp-tooltip-text, .ytp-tooltip-title,
    .ytp-chapter-container, .ytp-chapter-title,
    .ytp-multicam-button, .ytp-multicam-menu,
    .ytp-autonav-toggle-button-container,
    .ytp-autonav-endscreen-countdown-overlay,
    .ytp-autonav-endscreen-upnext-container,
    .ytp-autonav-endscreen-upnext-header,
    .ytp-autonav-endscreen-upnext-thumbnail,
    .ytp-autonav-endscreen-upnext-title,
    .ytp-autonav-endscreen-upnext-button,
    .ytp-videowall-still,
    .ytp-ad-visit-advertiser-button,
    .ytp-visit-advertiser-link, .ytp-ad-overlay-link,
    [class*="visit-advertiser"], .ytp-ad-text,
    .ytp-ad-progress, .ytp-ad-progress-list,
    .ytp-ad-player-overlay, .ytp-ad-player-overlay-layout,
    .ytp-ad-preview-container, .ytp-ad-message-container,
    .ytp-flyout-cta, .ytp-ad-action-interstitial,
    .ytp-ad-overlay-container, .ytp-ad-image-overlay,
    .ytp-featured-product, .ytp-product-picker,
    .ytp-info-panel-preview {
        display: none !important;
        visibility: hidden !important;
        opacity: 0 !important;
        pointer-events: none !important;
    }
    /* Keep the skip-ad button visible and tappable, styled as a full-width
       strip at the bottom of the web view. */
    .ytp-skip-ad-button, .ytp-ad-skip-button,
    .ytp-ad-skip-button-modern, .ytp-ad-skip-button-container,
    button[class*="skip"] {
        display: flex !important;
        visibility: visible !important;
        align-items: center !important;
        justify-content: center !important;
        position: fixed !important;
        bottom: 0 !important;
        left: 0 !important;
        width: 100vw !important;
        height: 48px !important;
        opacity: 1 !important;
        pointer-events: auto !important;
        z-index: 9999999 !important;
        background: rgba(0, 0, 0, 0.8) !important;
        color: #fff !important;
        font-size: 16px !important;
        border: none !important;
        border-radius: 0 !important;
        margin: 0 !important;
        padding: 0 !important;
        box-sizing: border-box !important;
    }
    .ytp-skip-ad-button *, .ytp-ad-skip-button *,
    .ytp-ad-skip-button-modern *, .ytp-ad-skip-button-container *,
    button[class*="skip"] * {
        border-radius: 0 !important;
    }
    """

    static func injectionScript(css: String) -> String {
        """
        (function() {
            function inject() {
                if (document.getElementById('sakura-yt-style')) return;
                var head = document.head || document.documentElement;
                if (!head) return;
                var s = document.createElement('style');
                s.id = 'sakura-yt-style';
                s.textContent = `\(css)`;
                head.appendChild(s);
            }
            inject();
            var observer = new MutationObserver(inject);
            if (document.documentElement) {
                observer.observe(document.documentElement, { childList: true, subtree: true });
            }
        })();
        """
    }
}
