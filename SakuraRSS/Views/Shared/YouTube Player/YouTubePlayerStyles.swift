import Foundation

nonisolated enum YouTubePlayerStyles {

    /// CSS for the YouTube embed-player page. The embed page only renders the
    /// player itself (no surrounding YouTube chrome), so we only need to:
    /// - stretch the player to fill the web view
    /// - hide the small bits the embed UI still draws on top of the video
    ///   (watermark, end-of-video card grid, suggested actions, etc.) so we
    ///   can use our own SwiftUI controls underneath.
    static let css = """
    html, body {
        margin: 0 !important;
        padding: 0 !important;
        width: 100% !important;
        height: 100% !important;
        background: #000 !important;
        overflow: hidden !important;
    }
    #player, .html5-video-player, .html5-video-container, video {
        width: 100% !important;
        height: 100% !important;
        max-width: none !important;
        max-height: none !important;
        background: #000 !important;
    }
    video {
        object-fit: contain !important;
    }
    .ytp-watermark, .ytp-show-tiles,
    .ytp-pause-overlay, .ytp-pause-overlay-container,
    .ytp-endscreen-content, .ytp-endscreen-element,
    .ytp-ce-element, .ytp-ce-covering-overlay,
    .ytp-ce-covering-image, .ytp-ce-element-shadow,
    .ytp-ce-video, .ytp-ce-playlist, .ytp-ce-channel,
    .ytp-cards-teaser, .ytp-cards-button, .ytp-cards-button-title,
    .ytp-suggested-action, .ytp-suggested-action-badge-container,
    .ytp-suggested-action-badge-expanded,
    .ytp-paid-content-overlay,
    .ytp-tooltip, .ytp-tooltip-text, .ytp-tooltip-title,
    .ytp-impression-link, .ytp-iv-player-content,
    .iv-branding, .iv-click-target, .branding-img-container,
    .ytp-ce-covering-shadow, .ytp-videowall-still {
        display: none !important;
        visibility: hidden !important;
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
            observer.observe(document.documentElement, { childList: true, subtree: true });
        })();
        """
    }
}
