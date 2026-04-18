import Foundation

nonisolated enum YouTubePlayerScripts {

    static let pipMessageHandlerName = "ytPiP"

    /// Injected at document start to suppress YouTube's Page Visibility-based
    /// auto-pause so audio keeps playing when the app is backgrounded.
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

    /// Attaches listeners to the video so PiP enter/leave events are forwarded
    /// to native code immediately, without waiting for the polling observer.
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

    /// Blocks autoplay by pausing the video whenever it tries to play until
    /// `window.__ytAutoplayBlocked` is cleared (by a native play action).
    static let autoplayBlocker = """
    (function() {
        window.__ytAutoplayBlocked = true;
        function attach(video) {
            if (!video || video.__ytAutoplayAttached) return;
            video.__ytAutoplayAttached = true;
            video.addEventListener('play', function() {
                if (window.__ytAutoplayBlocked) {
                    video.pause();
                }
            });
            if (!video.paused && window.__ytAutoplayBlocked) {
                video.pause();
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

    /// Re-plays the video if it pauses unexpectedly (for example because iOS
    /// throttled the backgrounded web view, or a stall happened during a
    /// network blip). User-initiated pauses are respected by checking
    /// `__ytUserPaused`, and the autoplay blocker takes precedence.
    static let playbackWatchdog = """
    (function() {
        function attach(video) {
            if (!video || video.__ytWatchdogAttached) return;
            video.__ytWatchdogAttached = true;
            video.addEventListener('pause', function() {
                if (window.__ytAutoplayBlocked) return;
                if (window.__ytUserPaused) return;
                var player = document.querySelector('.html5-video-player');
                if (player && player.classList.contains('ad-showing')) return;
                setTimeout(function() {
                    if (video.paused
                        && !window.__ytAutoplayBlocked
                        && !window.__ytUserPaused) {
                        video.play().catch(function() {});
                    }
                }, 250);
            });
            video.addEventListener('play', function() {
                window.__ytUserPaused = false;
            });
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

    /// Reads chapter markers from `ytInitialPlayerResponse` and returns an
    /// array of `{title, startSeconds}` entries, or an empty array if the
    /// video has no chapters.
    static let extractChapters = """
    (function() {
        try {
            var data = window.ytInitialPlayerResponse;
            if (!data || !data.playerOverlays) return [];
            var overlay = data.playerOverlays.playerOverlayRenderer;
            if (!overlay) return [];
            var outer = overlay.decoratedPlayerBarRenderer;
            if (!outer) return [];
            var inner = outer.decoratedPlayerBarRenderer;
            if (!inner || !inner.playerBar) return [];
            var markers = inner.playerBar.multiMarkersPlayerBarRenderer;
            if (!markers || !markers.markersMap) return [];
            var entry = null;
            for (var i = 0; i < markers.markersMap.length; i++) {
                var m = markers.markersMap[i];
                if (m && (m.key === 'DESCRIPTION_CHAPTERS' || m.key === 'AUTO_CHAPTERS')) {
                    entry = m;
                    break;
                }
            }
            if (!entry || !entry.value || !entry.value.chapters) return [];
            return entry.value.chapters.map(function(c) {
                var r = c && c.chapterRenderer;
                if (!r) return null;
                var title = '';
                if (r.title) {
                    if (typeof r.title.simpleText === 'string') {
                        title = r.title.simpleText;
                    } else if (r.title.runs && r.title.runs.length) {
                        title = r.title.runs.map(function(x) { return x.text || ''; }).join('');
                    }
                }
                var ms = parseInt(r.timeRangeStartMillis, 10);
                if (isNaN(ms)) ms = 0;
                return { title: title, startSeconds: ms / 1000.0 };
            }).filter(function(x) { return x && x.title; });
        } catch (e) {
            return [];
        }
    })();
    """
}
