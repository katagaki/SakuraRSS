import Foundation

nonisolated enum YouTubePlayerStyles {

    /// CSS injected into YouTube watch pages to hide chrome while keeping the video visible.
    static let css = """
    html, body {
        margin: 0 !important;
        padding: 0 !important;
        background: #000 !important;
        overflow: hidden !important;
        width: 100% !important;
        height: 100% !important;
    }
    /* Strip default margins on the page wrappers and fill the web view.
       The top:0 rule overrides YouTube's offset that reserves 48px for
       the (now-hidden) mobile topbar — without it, the player sits below
       an empty black band, most visible during ad transitions. */
    ytm-app, ytm-mobile-watch-flexy, ytm-watch,
    ytm-single-column-watch-next-results-renderer,
    ytm-watch-flexy, ytm-watch-flexy-content,
    .player-placeholder, .player-container,
    .player-screen, .player-size,
    #player, #player-container, #player-container-inner,
    #player-container-id, #player-control-container,
    #movie_player, .html5-video-player,
    .html5-video-container {
        margin: 0 !important;
        top: 0 !important;
        width: 100vw !important;
        height: 100vh !important;
        max-width: none !important;
        min-width: 0 !important;
    }
    /* Make the <video> element scale to fill the player. */
    video.html5-main-video, video.video-stream {
        width: 100vw !important;
        height: 100vh !important;
        object-fit: contain !important;
        left: 0 !important;
        top: 0 !important;
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
    /* Mobile YouTube Shorts overlay */
    ytm-reel-player-overlay-renderer,
    ytm-reel-player-header-renderer,
    ytm-shorts-lockup-view-model,
    ytm-shorts-compact-video-renderer,
    [class*="reel-player-overlay"],
    [class*="reel-player-header"],
    [class*="reel-player-metadata"],
    [class*="reel-player-info"],
    [class*="reel-action"],
    [class*="reel-video-action"],
    [class*="reel-video-metadata"],
    [class*="shorts-player-overlay"],
    [class*="shorts-action"],
    [class*="shorts-metadata"],
    [class*="shorts-player-header"],
    .reel-player-overlay-actions,
    .reel-player-overlay-action-buttons,
    .reel-player-overlay-main-content,
    reel-action-bar-view-model,
    like-button-view-model,
    .reel-video-action-button-container,
    .reel-video-action-button,
    .reel-video-metadata-panel,
    .reel-player-overlay-metadata-renderer,
    .reel-player-overlay-channel,
    .reel-player-header,
    .reel-player-progress-bar,
    .ytp-reel-progress-bar-line,
    .ytp-cued-thumbnail-overlay,
    .ytp-cued-thumbnail-overlay-image,
    /* Mobile-web touch overlay that briefly flashes the CC/settings/
       progress UI when the user seeks, even if the underlying chrome
       elements are hidden. */
    .layer.touch-controls,
    .player-controls,
    .player-controls-overlay,
    .player-controls-content,
    [class*="player-controls"],
    .ytp-touch-overlay,
    .ytp-tap-button,
    .ytp-tap-feedback,
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
    /* Desktop YouTube Shorts overlay */
    ytd-reel-player-overlay-renderer,
    ytd-reel-player-header-renderer,
    ytd-shorts-player-controls,
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
    /* YouTube's own player chrome */
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
    .ytp-ad-message-container,
    .ytp-flyout-cta, .ytp-ad-action-interstitial,
    .ytp-ad-overlay-container, .ytp-ad-image-overlay,
    .ytp-featured-product, .ytp-product-picker,
    .ytp-info-panel-preview {
        display: none !important;
        visibility: hidden !important;
        opacity: 0 !important;
        pointer-events: none !important;
    }
    /* Keep ad overlay ancestors in layout so the parked skip button has a
       bounding rect; the skip-button rule below flips visibility back. */
    .ytp-ad-player-overlay, .ytp-ad-player-overlay-layout,
    .ytp-ad-preview-container {
        background: transparent !important;
        visibility: hidden !important;
        pointer-events: none !important;
    }
    /* Park the skip-ad button offscreen but keep it in the DOM and clickable so
       our native Skip Ad button can trigger `.click()` on it. */
    .ytp-skip-ad-button, .ytp-ad-skip-button,
    .ytp-ad-skip-button-modern, .ytp-ad-skip-button-container,
    button[class*="skip"] {
        display: block !important;
        visibility: visible !important;
        position: fixed !important;
        top: -9999px !important;
        left: -9999px !important;
        width: 1px !important;
        height: 1px !important;
        opacity: 0 !important;
        pointer-events: auto !important;
        z-index: -1 !important;
    }
    """

    static func injectionScript(css: String) -> String {
        // Escape characters that would break out of the JS template literal.
        let safeCSS = css
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "${", with: "\\${")
        return """
        (function() {
            function log(msg) {
                try {
                    window.webkit.messageHandlers.ytDebug.postMessage(String(msg));
                } catch (e) {}
            }
            try {
                var cssText = `\(safeCSS)`;
                log('inject script start, head=' + !!document.head + ' doc=' + !!document.documentElement);
                function inject() {
                    if (document.getElementById('app-yt-style')) return;
                    var parent = document.head || document.documentElement;
                    if (!parent) { log('inject: no parent'); return; }
                    var s = document.createElement('style');
                    s.id = 'app-yt-style';
                    s.textContent = cssText;
                    parent.appendChild(s);
                    log('inject: appended style len=' + cssText.length + ' parent=' + parent.tagName);
                }
                inject();
                var observer = new MutationObserver(inject);
                if (document.documentElement) {
                    observer.observe(document.documentElement, { childList: true, subtree: true });
                    log('observer attached');
                } else {
                    log('no documentElement for observer');
                }
            } catch (e) {
                log('inject error: ' + e.message + ' stack=' + (e.stack || ''));
            }
        })();
        """
    }
}
