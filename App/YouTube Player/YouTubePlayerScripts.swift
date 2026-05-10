import Foundation
import Hanami

// swiftlint:disable:next type_body_length
nonisolated enum YouTubePlayerScripts {

    static let pipMessageHandlerName = "ytPiP"
    static let playbackMessageHandlerName = "ytPlayback"

    /// Hides background/PiP/page-lifecycle signals from page scripts so YouTube
    /// has no reason to pause the video, while preserving native access via
    /// `window.__yt.*` (saved originals before the patches were applied).
    ///
    /// This replaces a more invasive approach that overrode `HTMLMediaElement.pause`.
    /// Blocking detection at the source means there is no pause attempt to undo,
    /// which is friendlier to YouTube's internal state machine and to ad transitions.
    static let mediaIsolationBootstrap = """
    (function() {
        if (window.__yt) return;

        var origAdd = EventTarget.prototype.addEventListener;
        var origRemove = EventTarget.prototype.removeEventListener;
        var origDispatch = EventTarget.prototype.dispatchEvent;
        var pipDescriptor = Object.getOwnPropertyDescriptor(
            Document.prototype, 'pictureInPictureElement'
        );
        // Save the real PiP entry/exit methods *before* we install no-op
        // overrides on the prototypes. YouTube's player code can only see
        // the patched methods, but our app keeps native control via
        // `__yt.enterPiP` / `__yt.exitPiP` below.
        var origExitPiP = Document.prototype.exitPictureInPicture;
        var origRequestPiP = HTMLVideoElement.prototype.requestPictureInPicture;
        var origWebkitSetPM = HTMLVideoElement.prototype.webkitSetPresentationMode;

        window.__yt = {
            autoplayBlocked: false,
            userPaused: false,
            // Set to true by the PiP bridge when we exit PiP without Swift
            // having flagged the exit as deliberate (i.e., iOS tore PiP down
            // during background). Suppresses the pause-guard auto-resume so
            // audio doesn't keep playing without the visual PiP context.
            // Cleared when Swift initiates a play.
            exitedPiPRecently: false,
            // Swift sets this before calling `exitPictureInPicture()` /
            // `webkitSetPresentationMode('inline')` so the PiP bridge knows
            // the exit is user-initiated and not a system tear-down.
            expectingPiPExit: false,
            addListener: function(target, type, handler, options) {
                return origAdd.call(target, type, handler, options);
            },
            removeListener: function(target, type, handler, options) {
                return origRemove.call(target, type, handler, options);
            },
            // True if any video is in PiP. Checks the iOS-specific
            // `webkitPresentationMode` first since `pictureInPictureElement`
            // is unreliable in WKWebView's native PiP path.
            isInPiP: function() {
                var videos = document.querySelectorAll('video');
                for (var i = 0; i < videos.length; i++) {
                    if (videos[i].webkitPresentationMode === 'picture-in-picture') {
                        return true;
                    }
                }
                var el = (pipDescriptor && pipDescriptor.get)
                    ? pipDescriptor.get.call(document) : null;
                return !!el;
            },
            // Native PiP entry, bypassing our prototype overrides. Prefers the
            // W3C API (which routes through AVPictureInPictureController on iOS)
            // and falls back to the iOS-only setter.
            enterPiP: function(video) {
                if (!video) return;
                if (origRequestPiP) {
                    var p = origRequestPiP.call(video);
                    if (p && typeof p.catch === 'function') p.catch(function(){});
                } else if (origWebkitSetPM) {
                    origWebkitSetPM.call(video, 'picture-in-picture');
                }
            },
            // Native PiP exit, bypassing our prototype overrides.
            exitPiP: function(video) {
                if (origExitPiP) {
                    var p = origExitPiP.call(document);
                    if (p && typeof p.catch === 'function') p.catch(function(){});
                } else if (video && origWebkitSetPM) {
                    origWebkitSetPM.call(video, 'inline');
                }
            },
            // Diagnostic log to the native `ytDebug` message handler. The
            // handler is registered only in DEBUG builds; in Release these
            // calls silently no-op via the try/catch.
            log: function(msg) {
                try {
                    if (window.webkit && window.webkit.messageHandlers
                        && window.webkit.messageHandlers.ytDebug) {
                        window.webkit.messageHandlers.ytDebug.postMessage(
                            '[BG ' + Date.now() + '] ' + msg
                        );
                    }
                } catch (e) {}
            }
        };

        var BLOCKED = {
            visibilitychange: 1, webkitvisibilitychange: 1,
            enterpictureinpicture: 1, leavepictureinpicture: 1,
            webkitpresentationmodechanged: 1,
            pagehide: 1, pageshow: 1, freeze: 1, resume: 1
        };

        // Window-level `blur`/`focus` is a background-detection signal on
        // iOS WKWebView - `blur` fires when the app deactivates. Element-
        // level `focus`/`blur` (form inputs etc.) must still work, so we
        // only filter when registered on window/document/body.
        function isWindowLevel(target) {
            return target === window
                || target === document
                || target === document.documentElement
                || target === document.body;
        }

        EventTarget.prototype.addEventListener = function(type, listener, options) {
            if (BLOCKED[type]) return;
            if ((type === 'blur' || type === 'focus') && isWindowLevel(this)) {
                return;
            }
            return origAdd.call(this, type, listener, options);
        };

        EventTarget.prototype.dispatchEvent = function(event) {
            if (event && BLOCKED[event.type]) return true;
            return origDispatch.call(this, event);
        };

        function defineConst(target, name, value) {
            try {
                Object.defineProperty(target, name, {
                    configurable: true,
                    get: function() { return value; }
                });
            } catch (e) {}
        }
        defineConst(Document.prototype, 'hidden', false);
        defineConst(Document.prototype, 'webkitHidden', false);
        defineConst(Document.prototype, 'visibilityState', 'visible');
        defineConst(Document.prototype, 'webkitVisibilityState', 'visible');
        defineConst(Document.prototype, 'pictureInPictureElement', null);

        function neuterOn(target, names) {
            names.forEach(function(name) {
                try {
                    Object.defineProperty(target, name, {
                        configurable: true,
                        get: function() { return null; },
                        set: function() {}
                    });
                } catch (e) {}
            });
        }
        neuterOn(Document.prototype, ['onvisibilitychange']);
        neuterOn(HTMLVideoElement.prototype, [
            'onenterpictureinpicture',
            'onleavepictureinpicture',
            'onwebkitpresentationmodechanged'
        ]);
        neuterOn(Window.prototype, [
            'onpagehide', 'onpageshow', 'onfreeze', 'onresume',
            'onblur', 'onfocus'
        ]);

        // Hard-block YouTube's only PiP-control code path. The single toggle
        // method in the player JS calls these prototype methods; no other
        // path in the player uses PiP APIs. Our app retains native control
        // through `__yt.enterPiP` / `__yt.exitPiP` (saved originals above).
        function rejectedPromise() {
            return Promise && Promise.reject
                ? Promise.reject(new Error('blocked'))
                : undefined;
        }
        try {
            Document.prototype.exitPictureInPicture = function() {
                window.__yt.log('PAGE call: exitPictureInPicture (blocked)');
                return rejectedPromise();
            };
        } catch (e) {}
        try {
            HTMLVideoElement.prototype.requestPictureInPicture = function() {
                window.__yt.log('PAGE call: requestPictureInPicture (blocked)');
                return rejectedPromise();
            };
        } catch (e) {}
        try {
            if (origWebkitSetPM) {
                HTMLVideoElement.prototype.webkitSetPresentationMode =
                    function(mode) {
                        window.__yt.log(
                            'PAGE call: webkitSetPresentationMode("'
                            + mode + '") (blocked)'
                        );
                    };
            }
        } catch (e) {}

        // Attach passive listeners on every event we filter, plus key video
        // events, so we can see exactly what fires on iOS during background
        // transitions. Uses saved `origAdd` so listeners aren't filtered.
        function watch(target, type, label) {
            origAdd.call(target, type, function(e) {
                window.__yt.log(label + ' (vis=' + document.visibilityState + ')');
            }, true);
        }
        ['visibilitychange', 'webkitvisibilitychange'].forEach(function(t) {
            watch(document, t, 'document.' + t);
        });
        ['blur', 'focus', 'pagehide', 'pageshow', 'freeze', 'resume'].forEach(
            function(t) { watch(window, t, 'window.' + t); }
        );

        var VIDEO_EVENTS = [
            'enterpictureinpicture', 'leavepictureinpicture',
            'webkitpresentationmodechanged',
            'pause', 'play', 'ended', 'waiting', 'stalled',
            'suspend', 'emptied', 'abort'
        ];
        function attachVideoLog(video) {
            if (video.__ytEventLogAttached) return;
            video.__ytEventLogAttached = true;
            VIDEO_EVENTS.forEach(function(type) {
                origAdd.call(video, type, function() {
                    window.__yt.log(
                        'video.' + type
                        + ' paused=' + video.paused
                        + ' mode=' + (video.webkitPresentationMode || 'n/a')
                        + ' t=' + (isFinite(video.currentTime)
                            ? video.currentTime.toFixed(2) : '?')
                    );
                }, true);
            });
        }
        function scanVideos() {
            document.querySelectorAll('video').forEach(attachVideoLog);
        }
        scanVideos();
        var videoObserver = new MutationObserver(scanVideos);
        if (document.documentElement) {
            videoObserver.observe(document.documentElement,
                { childList: true, subtree: true });
        }
    })();
    """

    /// Resumes the video when something pauses it that isn't the user. Defaults
    /// to "resume on any pause". Swift sets `__yt.userPaused = true` before
    /// deliberate pauses, and `__yt.autoplayBlocked` defers to the autoplay
    /// blocker. End-of-video and within-tail pauses are left alone.
    ///
    /// This catches:
    ///   - WebKit suspending WKWebView media on app background (no JS pause to
    ///     intercept; we only see the resulting `pause` event)
    ///   - any YouTube pause path our isolation bootstrap didn't anticipate
    static let pauseGuard = """
    (function() {
        function attach(video) {
            if (!video || video.__ytPauseGuardAttached) return;
            video.__ytPauseGuardAttached = true;
            window.__yt.addListener(video, 'pause', function() {
                if (window.__yt.userPaused === true) return;
                if (window.__yt.autoplayBlocked === true) return;
                // System tore down PiP, don't resume audio "headlessly"
                // when the user has no visual PiP indicator anymore.
                if (window.__yt.exitedPiPRecently === true) return;
                if (video.ended) return;
                if (video.duration > 0
                    && video.currentTime >= video.duration - 0.25) return;
                var p = video.play();
                if (p && typeof p.catch === 'function') { p.catch(function(){}); }
            }, true);
        }
        function scan() { document.querySelectorAll('video').forEach(attach); }
        scan();
        var observer = new MutationObserver(scan);
        if (document.documentElement) {
            observer.observe(document.documentElement, { childList: true, subtree: true });
        }
    })();
    """

    /// Plays the next ready `<video>` after `__yt.armAutoplay(ms)` is called.
    static let autoplayArmer = """
    (function() {
        if (!window.__yt) return;
        if (window.__yt.armAutoplay) return;
        window.__yt.autoplayArmedUntil = 0;

        function armed() {
            return Date.now() < (window.__yt.autoplayArmedUntil || 0);
        }

        function tryPlay(v) {
            if (!v || !v.paused || v.ended) return;
            if (window.__yt.userPaused === true) return;
            if (window.__yt.autoplayBlocked === true) return;
            if (window.__yt.exitedPiPRecently === true) return;
            try {
                var p = v.play();
                if (p && typeof p.catch === 'function') p.catch(function(){});
            } catch (e) {}
        }

        function attach(v) {
            if (!v || v.__ytAutoplayArmAttached) return;
            v.__ytAutoplayArmAttached = true;
            ['canplay', 'loadeddata', 'loadedmetadata', 'playing'].forEach(function(evt) {
                window.__yt.addListener(v, evt, function() {
                    if (armed()) tryPlay(v);
                }, true);
            });
        }

        function scan() { document.querySelectorAll('video').forEach(attach); }
        scan();
        var observer = new MutationObserver(scan);
        if (document.documentElement) {
            observer.observe(document.documentElement,
                { childList: true, subtree: true });
        }

        window.__yt.armAutoplay = function(durationMs) {
            var dur = (typeof durationMs === 'number' && durationMs > 0)
                ? durationMs : 12000;
            window.__yt.autoplayArmedUntil = Date.now() + dur;
            window.__yt.autoplayBlocked = false;
            window.__yt.userPaused = false;
            window.__yt.exitedPiPRecently = false;
            scan();
            (function tick() {
                if (!armed()) return;
                document.querySelectorAll('video').forEach(tryPlay);
                setTimeout(tick, 200);
            })();
        };
    })();
    """
}
