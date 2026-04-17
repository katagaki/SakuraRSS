import Foundation

enum YouTubePlayerScripts {

    static let pipMessageHandlerName = "sakuraPiP"

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
            if (!video || video.__sakuraPiPAttached) return;
            video.__sakuraPiPAttached = true;
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
    /// `window.__sakuraAutoplayBlocked` is cleared (by a native play action).
    static let autoplayBlocker = """
    (function() {
        window.__sakuraAutoplayBlocked = true;
        function attach(video) {
            if (!video || video.__sakuraAutoplayAttached) return;
            video.__sakuraAutoplayAttached = true;
            video.addEventListener('play', function() {
                if (window.__sakuraAutoplayBlocked) {
                    video.pause();
                }
            });
            if (!video.paused && window.__sakuraAutoplayBlocked) {
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
}
