import Foundation

// swiftlint:disable:next type_body_length
nonisolated enum YouTubePlayerScripts {

    static let pipMessageHandlerName = "ytPiP"

    /// Suppresses YouTube's visibility-based auto-pause so audio continues when backgrounded.
    static let backgroundPlaybackOverride = """
    (function() {
        try {
            Object.defineProperty(Document.prototype, 'hidden', {
                configurable: true, get: function() { return false; }
            });
            Object.defineProperty(Document.prototype, 'visibilityState', {
                configurable: true, get: function() { return 'visible'; }
            });
            Object.defineProperty(Document.prototype, 'webkitHidden', {
                configurable: true, get: function() { return false; }
            });
            Object.defineProperty(Document.prototype, 'webkitVisibilityState', {
                configurable: true, get: function() { return 'visible'; }
            });
        } catch (e) {}

        var origAdd = EventTarget.prototype.addEventListener;
        EventTarget.prototype.addEventListener = function(type, listener, options) {
            if (type === 'visibilitychange' || type === 'webkitvisibilitychange') {
                return;
            }
            return origAdd.call(this, type, listener, options);
        };

        try {
            Object.defineProperty(Document.prototype, 'onvisibilitychange', {
                configurable: true, get: function() { return null; }, set: function() {}
            });
        } catch (e) {}

        var origDispatch = EventTarget.prototype.dispatchEvent;
        EventTarget.prototype.dispatchEvent = function(event) {
            if (event && (event.type === 'visibilitychange' || event.type === 'webkitvisibilitychange')) {
                return true;
            }
            return origDispatch.call(this, event);
        };
    })();
    """

    /// Blocks YouTube's internal `video.pause()` calls (e.g. on visibility change or
    /// PiP transitions) so there is no pause to fade out of. Pauses are only honored
    /// when Swift first sets `window.__ytUserPaused = true` or when the video has ended.
    static let pauseOverride = """
    (function() {
        var proto = HTMLMediaElement.prototype;
        if (proto.__ytPauseOverridden) return;
        proto.__ytPauseOverridden = true;
        var originalPause = proto.pause;
        proto.pause = function() {
            if (window.__ytUserPaused === true || this.ended) {
                return originalPause.apply(this, arguments);
            }
        };
    })();
    """

    /// Safety net for native pauses that bypass the JS pause override (e.g. WebKit
    /// suspending media directly). Resumes immediately in the same event loop.
    static let pauseGuard = """
    (function() {
        function attach(video) {
            if (!video || video.__ytPauseGuardAttached) return;
            video.__ytPauseGuardAttached = true;
            video.addEventListener('pause', function() {
                if (window.__ytUserPaused === true) return;
                if (video.ended) return;
                if (video.currentTime > 0 && video.duration > 0
                    && video.currentTime >= video.duration - 0.25) return;
                var promise = video.play();
                if (promise && typeof promise.catch === 'function') {
                    promise.catch(function(){});
                }
            }, true);
        }
        function scan() {
            document.querySelectorAll('video').forEach(attach);
        }
        scan();
        var observer = new MutationObserver(scan);
        if (document.documentElement) {
            observer.observe(document.documentElement, { childList: true, subtree: true });
        }
    })();
    """

    /// Prevents YouTube from forcing PiP to close during ads by neutralizing
    /// any `disablePictureInPicture` writes on `<video>` elements.
    static let pipDisableOverride = """
    (function() {
        try {
            var proto = HTMLVideoElement.prototype;
            if (!proto.__ytPiPDisableOverridden) {
                proto.__ytPiPDisableOverridden = true;
                Object.defineProperty(proto, 'disablePictureInPicture', {
                    configurable: true,
                    get: function() { return false; },
                    set: function() {}
                });
            }
        } catch (e) {}
        function strip(video) {
            if (!video) return;
            try { video.removeAttribute('disablepictureinpicture'); } catch (e) {}
            try { video.removeAttribute('disablePictureInPicture'); } catch (e) {}
        }
        function scan() { document.querySelectorAll('video').forEach(strip); }
        scan();
        var observer = new MutationObserver(scan);
        if (document.documentElement) {
            observer.observe(document.documentElement, {
                childList: true, subtree: true,
                attributes: true,
                attributeFilter: ['disablepictureinpicture', 'disablePictureInPicture']
            });
        }
    })();
    """

    /// Re-routes the system PiP next/previous track controls during ads:
    /// previous-track is disabled, next-track triggers ad skipping when available.
    static let pipAdControls = """
    (function() {
        if (!('mediaSession' in navigator)) return;
        var ms = navigator.mediaSession;
        var origSet = ms.setActionHandler.bind(ms);
        var stored = { previoustrack: null, nexttrack: null };
        var lastApplied = { previoustrack: undefined, nexttrack: undefined };

        ms.setActionHandler = function(action, handler) {
            if (action === 'previoustrack' || action === 'nexttrack') {
                stored[action] = handler || null;
                apply();
                return;
            }
            return origSet(action, handler);
        };

        function findSkipButton() {
            var selector = '.ytp-skip-ad-button, .ytp-ad-skip-button,'
                + ' .ytp-ad-skip-button-modern, .ytp-skip-ad-button-text';
            var btns = document.querySelectorAll(selector);
            for (var i = 0; i < btns.length; i++) {
                var b = btns[i];
                if (b.disabled) continue;
                var r = b.getBoundingClientRect();
                if (r.width === 0 && r.height === 0) continue;
                if (getComputedStyle(b).visibility === 'hidden') continue;
                return b;
            }
            return null;
        }

        function performSkipAd() {
            var btn = findSkipButton();
            if (btn) {
                var t = btn.closest('button') || btn;
                try { t.click(); } catch (e) {}
                try {
                    ['pointerdown','mousedown','pointerup','mouseup','click'].forEach(function(type) {
                        var Ctor = (type.indexOf('pointer') === 0 && window.PointerEvent)
                            ? window.PointerEvent : MouseEvent;
                        t.dispatchEvent(new Ctor(type, {
                            bubbles: true, cancelable: true, view: window,
                            button: 0, buttons: 1
                        }));
                    });
                } catch (e) {}
            }
            var p = document.querySelector('.html5-video-player');
            var v = document.querySelector('video');
            if (p && p.classList.contains('ad-showing')
                && v && isFinite(v.duration) && v.duration > 0) {
                v.currentTime = Math.max(v.duration - 0.05, v.currentTime);
            }
        }

        function apply() {
            var p = document.querySelector('.html5-video-player');
            var isAd = p ? p.classList.contains('ad-showing') : false;
            var skippable = isAd && !!findSkipButton();

            var prev, next;
            if (isAd) {
                prev = null;
                next = skippable ? performSkipAd : null;
            } else {
                prev = stored.previoustrack;
                next = stored.nexttrack;
            }

            if (lastApplied.previoustrack !== prev) {
                try { origSet('previoustrack', prev); } catch (e) {}
                lastApplied.previoustrack = prev;
            }
            if (lastApplied.nexttrack !== next) {
                try { origSet('nexttrack', next); } catch (e) {}
                lastApplied.nexttrack = next;
            }
        }

        setInterval(apply, 500);
        apply();
    })();
    """

    /// Forwards PiP enter/leave events to native code immediately.
    static let pipEventBridge = """
    (function() {
        function send(state) {
            try {
                window.webkit.messageHandlers.\(pipMessageHandlerName).postMessage(state);
            } catch (e) {}
        }
        function attach(video) {
            if (!video || video.__ytPiPAttached) return;
            video.__ytPiPAttached = true;
            video.addEventListener('enterpictureinpicture', function() { send('enter'); });
            video.addEventListener('leavepictureinpicture', function() { send('leave'); });
        }
        function tryAttach() {
            var videos = document.querySelectorAll('video');
            videos.forEach(attach);
            return videos.length > 0;
        }
        tryAttach();
        var observer = new MutationObserver(function() { tryAttach(); });
        if (document.documentElement) {
            observer.observe(document.documentElement, { childList: true, subtree: true });
        }
    })();
    """

    /// Blocks autoplay until `window.__ytAutoplayBlocked` is cleared by a native play action.
    /// Sets `__ytUserPaused = true` before pausing so the pause survives `pauseOverride`
    /// and is not re-played by `pauseGuard`.
    static let autoplayBlocker = """
    (function() {
        window.__ytAutoplayBlocked = true;
        function block(video) {
            window.__ytUserPaused = true;
            video.pause();
        }
        function attach(video) {
            if (!video || video.__ytAutoplayAttached) return;
            video.__ytAutoplayAttached = true;
            video.addEventListener('play', function() {
                if (window.__ytAutoplayBlocked) {
                    block(video);
                }
            });
            if (!video.paused && window.__ytAutoplayBlocked) {
                block(video);
            }
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
