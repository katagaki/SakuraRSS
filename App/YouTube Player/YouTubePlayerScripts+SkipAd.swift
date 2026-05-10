import Foundation
import Hanami

extension YouTubePlayerScripts {

    /// Blocks autoplay until `window.__yt.autoplayBlocked` is cleared by a native play action.
    static let autoplayBlocker = """
    (function() {
        window.__yt.autoplayBlocked = true;
        function attach(video) {
            if (!video || video.__ytAutoplayAttached) return;
            video.__ytAutoplayAttached = true;
            video.addEventListener('play', function() {
                if (window.__yt.autoplayBlocked) { video.pause(); }
            });
            if (!video.paused && window.__yt.autoplayBlocked) { video.pause(); }
        }
        function tryAttach() {
            document.querySelectorAll('video').forEach(attach);
        }
        tryAttach();
        var observer = new MutationObserver(tryAttach);
        if (document.documentElement) {
            observer.observe(document.documentElement, { childList: true, subtree: true });
        }
    })();
    """

    /// Inline JS expression that returns the visible ad-skip button element or null.
    static let findSkipButtonExpression = """
    (function() {
        var selector = '.ytp-skip-ad-button, .ytp-ad-skip-button,'
            + ' .ytp-ad-skip-button-modern, .ytp-skip-ad-button-text';
        var buttons = document.querySelectorAll(selector);
        for (var i = 0; i < buttons.length; i++) {
            var btn = buttons[i];
            if (btn.disabled) continue;
            var rect = btn.getBoundingClientRect();
            if (rect.width === 0 && rect.height === 0) continue;
            if (getComputedStyle(btn).visibility === 'hidden') continue;
            return btn;
        }
        return null;
    })()
    """

    /// Skips the current ad either by clicking YouTube's skip button or by
    /// seeking the ad video to its end. Returns a bool indicating any action.
    static var skipAd: String {
        #if DEBUG
        let dbgHelper = """
        function dbg(msg) {
            try { window.webkit.messageHandlers.ytDebug.postMessage('[skipAd] ' + msg); } catch (e) {}
        }
        """
        #else
        let dbgHelper = "function dbg(){}"
        #endif
        return """
        (function() {
            \(dbgHelper)
            dbg('invoked at ' + new Date().toISOString());
            var acted = false;
            var btn = \(findSkipButtonExpression);
            dbg('findSkipButton: ' + (btn
                ? 'found tag=' + btn.tagName + ' class="' + btn.className + '"'
                    + ' text="' + (btn.textContent || '').trim().slice(0, 60) + '"'
                : 'not found'));
            if (btn) {
                var target = btn.closest('button') || btn;
                dbg('target: tag=' + target.tagName + ' class="' + target.className + '"'
                    + ' disabled=' + !!target.disabled);
                try {
                    var r = target.getBoundingClientRect();
                    dbg('rect: x=' + r.left.toFixed(1) + ' y=' + r.top.toFixed(1)
                        + ' w=' + r.width.toFixed(1) + ' h=' + r.height.toFixed(1));
                    var cs = getComputedStyle(target);
                    dbg('style: display=' + cs.display + ' visibility=' + cs.visibility
                        + ' opacity=' + cs.opacity + ' pointerEvents=' + cs.pointerEvents);
                } catch (e) { dbg('rect/style err: ' + e.message); }
                try { target.focus(); dbg('focus ok'); }
                catch (e) { dbg('focus err: ' + e.message); }
                try { target.click(); acted = true; dbg('click() ok'); }
                catch (e) { dbg('click() err: ' + e.message); }
                try {
                    var types = ['pointerdown', 'mousedown', 'pointerup', 'mouseup', 'click'];
                    types.forEach(function(type) {
                        var Ctor = (type.indexOf('pointer') === 0 && window.PointerEvent)
                            ? window.PointerEvent : MouseEvent;
                        var ev = new Ctor(type, {
                            bubbles: true, cancelable: true, view: window,
                            button: 0, buttons: 1
                        });
                        var ok = target.dispatchEvent(ev);
                        dbg('dispatch ' + type + ' -> defaultNotPrevented=' + ok
                            + ' isTrusted=' + ev.isTrusted);
                    });
                    acted = true;
                } catch (e) { dbg('dispatch err: ' + e.message); }
            }
            try {
                var player = document.querySelector('.html5-video-player');
                var showingAd = player && player.classList.contains('ad-showing');
                var video = document.querySelector('video');
                dbg('player=' + !!player + ' ad-showing=' + !!showingAd
                    + ' video=' + !!video
                    + ' duration=' + (video ? video.duration : 'n/a')
                    + ' currentTime=' + (video ? video.currentTime : 'n/a')
                    + ' paused=' + (video ? video.paused : 'n/a'));
                if (showingAd && video && isFinite(video.duration) && video.duration > 0) {
                    var to = Math.max(video.duration - 0.05, video.currentTime);
                    video.currentTime = to;
                    dbg('seek fallback -> ' + to);
                    acted = true;
                } else {
                    dbg('seek fallback skipped');
                }
            } catch (e) { dbg('seek err: ' + e.message); }
            if (acted) {
                if (window.__yt && typeof window.__yt.armAutoplay === 'function') {
                    window.__yt.armAutoplay(12000);
                    dbg('armAutoplay(12000) called');
                } else {
                    window.__yt.autoplayBlocked = false;
                    window.__yt.userPaused = false;
                    window.__yt.exitedPiPRecently = false;
                    dbg('armAutoplay missing, flags cleared');
                }
            }
            dbg('done acted=' + acted);
            return acted;
        })();
        """
    }

    /// Returns `[{title, startSeconds}]` for chapters, empty when none exist.
    static let extractChapters = """
    (function() {
        function textFrom(v) {
            if (!v) return '';
            if (typeof v === 'string') return v;
            if (typeof v.simpleText === 'string') return v.simpleText;
            if (v.runs && v.runs.length) {
                return v.runs.map(function(x) { return x.text || ''; }).join('');
            }
            return '';
        }
        function parseTimestamp(s) {
            if (!s) return 0;
            var parts = s.split(':').map(function(p) { return parseInt(p, 10) || 0; });
            if (parts.length === 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
            if (parts.length === 2) return parts[0] * 60 + parts[1];
            return parts[0] || 0;
        }
        function fromPlayerOverlays(data) {
            try {
                var overlay = data && data.playerOverlays
                    && data.playerOverlays.playerOverlayRenderer;
                var outer = overlay && overlay.decoratedPlayerBarRenderer;
                var inner = outer && outer.decoratedPlayerBarRenderer;
                var bar = inner && inner.playerBar;
                var markers = bar && bar.multiMarkersPlayerBarRenderer;
                if (!markers || !markers.markersMap) return [];
                var entry = null;
                for (var i = 0; i < markers.markersMap.length; i++) {
                    var m = markers.markersMap[i];
                    if (m && (m.key === 'DESCRIPTION_CHAPTERS' || m.key === 'AUTO_CHAPTERS')) {
                        entry = m; break;
                    }
                }
                if (!entry || !entry.value || !entry.value.chapters) return [];
                return entry.value.chapters.map(function(c) {
                    var r = c && c.chapterRenderer;
                    if (!r) return null;
                    var ms = parseInt(r.timeRangeStartMillis, 10);
                    if (isNaN(ms)) ms = 0;
                    return { title: textFrom(r.title), startSeconds: ms / 1000.0 };
                }).filter(function(x) { return x && x.title; });
            } catch (e) { return []; }
        }
        function fromEngagementPanels(data) {
            try {
                var panels = data && data.engagementPanels;
                if (!panels || !panels.length) return [];
                for (var i = 0; i < panels.length; i++) {
                    var p = panels[i] && panels[i].engagementPanelSectionListRenderer;
                    if (!p) continue;
                    var target = p.targetId || p.panelIdentifier || '';
                    if (target.indexOf('macro-markers') === -1
                        && target.indexOf('chapters') === -1) continue;
                    var list = p.content && p.content.macroMarkersListRenderer;
                    if (!list || !list.contents) continue;
                    var out = [];
                    for (var j = 0; j < list.contents.length; j++) {
                        var item = list.contents[j]
                            && list.contents[j].macroMarkersListItemRenderer;
                        if (!item) continue;
                        var title = textFrom(item.title);
                        if (!title) continue;
                        var startSec = 0;
                        var endpoint = item.onTap && item.onTap.watchEndpoint;
                        if (endpoint && typeof endpoint.startTimeSeconds === 'number') {
                            startSec = endpoint.startTimeSeconds;
                        } else {
                            startSec = parseTimestamp(textFrom(item.timeDescription));
                        }
                        out.push({ title: title, startSeconds: startSec });
                    }
                    if (out.length) return out;
                }
                return [];
            } catch (e) { return []; }
        }
        var pr = window.ytInitialPlayerResponse;
        var pd = window.ytInitialData;
        var result = fromPlayerOverlays(pr);
        if (!result.length) result = fromEngagementPanels(pd);
        if (!result.length) result = fromEngagementPanels(pr);
        return result;
    })();
    """
}
