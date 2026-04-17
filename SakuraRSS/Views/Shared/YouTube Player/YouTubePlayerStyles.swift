import Foundation

nonisolated enum YouTubePlayerStyles {

    static let css = """
    * { margin: 0 !important; padding: 0 !important; }
    body { overflow: hidden !important; background: #000 !important; }
    #player, .html5-video-player, video {
        position: fixed !important;
        top: 0 !important;
        left: 0 !important;
        width: 100vw !important;
        height: 100vh !important;
        z-index: 999999 !important;
    }
    ytd-app, #content, #page-manager, ytd-watch-flexy,
    #columns, #primary, #primary-inner, #player-container-outer,
    #player-container-inner, #player-container,
    #movie_player, .html5-video-container {
        position: fixed !important;
        top: 0 !important; left: 0 !important;
        width: 100vw !important; height: 100vh !important;
        max-width: none !important; max-height: none !important;
        min-width: 0 !important; min-height: 0 !important;
        margin: 0 !important; padding: 0 !important;
        overflow: hidden !important;
    }
    #secondary, #related, #comments, #info, #meta,
    #above-the-fold, #below, ytd-watch-metadata,
    #masthead-container, #guide, ytd-masthead,
    ytd-mini-guide-renderer, #chat,
    header, ytm-mobile-topbar-renderer,
    .player-controls-top,
    ytd-engagement-panel-section-list-renderer,
    tp-yt-app-drawer, #description, #actions,
    ytd-merch-shelf-renderer, ytd-info-panel-content-renderer,
    .ytd-watch-next-secondary-results-renderer,
    #chips, #header, .ytd-rich-grid-renderer,
    ytd-feed-filter-chip-bar-renderer,
    ytd-compact-promoted-video-renderer,
    tp-yt-paper-dialog, ytd-popup-container,
    ytd-consent-bump-v2-lightbox,
    .ytp-chrome-top, .ytp-chrome-bottom, .ytp-chrome-controls,
    .ytp-title, .ytp-title-text, .ytp-title-channel,
    .ytp-title-link, .ytp-title-expanded-heading,
    .ytp-overflow-button, .ytp-settings-button,
    .ytp-share-button, .ytp-watch-later-button,
    .ytp-gradient-top, .ytp-gradient-bottom,
    .ytp-left-controls, .ytp-right-controls,
    .ytp-progress-bar-container, .ytp-progress-bar,
    .ytp-scrubber-container, .ytp-time-display,
    .ytp-play-button, .ytp-pause-button,
    .ytp-next-button, .ytp-prev-button,
    .ytp-mute-button, .ytp-volume-panel, .ytp-volume-slider,
    .ytp-subtitles-button, .ytp-captions-button,
    .ytp-fullscreen-button, .ytp-size-button,
    .ytp-miniplayer-button, .ytp-pip-button,
    .ytp-autonav-toggle-button-container,
    .ytp-autonav-endscreen-countdown-overlay,
    .ytp-autonav-endscreen-upnext-container,
    .ytp-autonav-endscreen-upnext-header,
    .ytp-autonav-endscreen-upnext-thumbnail,
    .ytp-autonav-endscreen-upnext-title,
    .ytp-autonav-endscreen-upnext-button,
    .ytp-large-play-button, .ytp-cued-thumbnail-overlay,
    .ytp-spinner, .ytp-spinner-container,
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
    .ytp-exp-bottom-control-flexbox,
    .ytp-menuitem, .ytp-panel, .ytp-panel-menu, .ytp-popup,
    .ytp-contextmenu, .ytp-remote,
    .ytp-offline-slate, .ytp-error,
    .ytp-ad-visit-advertiser-button,
    .ytp-visit-advertiser-link, .ytp-ad-overlay-link,
    [class*="visit-advertiser"], .ytp-ad-text,
    .ytp-ad-progress, .ytp-ad-progress-list,
    .ytp-ad-player-overlay, .ytp-ad-player-overlay-layout,
    .ytp-ad-preview-container, .ytp-ad-message-container,
    .ytp-flyout-cta, .ytp-ad-action-interstitial,
    .ytp-ad-overlay-container, .ytp-ad-image-overlay,
    .ytp-featured-product, .ytp-product-picker,
    .ytp-info-panel-preview, .ytp-videowall-still {
        display: none !important;
        visibility: hidden !important;
        height: 0 !important;
        width: 0 !important;
        opacity: 0 !important;
        pointer-events: none !important;
    }
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
            var style = document.createElement('style');
            style.textContent = `\(css)`;
            document.head.appendChild(style);

            // Re-apply after dynamic content loads
            var observer = new MutationObserver(function() {
                if (!document.getElementById('sakura-yt-style')) {
                    var s = document.createElement('style');
                    s.id = 'sakura-yt-style';
                    s.textContent = `\(css)`;
                    document.head.appendChild(s);
                }
            });
            observer.observe(document.body, { childList: true, subtree: true });
        })();
        """
    }
}
