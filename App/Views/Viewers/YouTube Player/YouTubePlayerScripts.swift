import Foundation

// swiftlint:disable:next type_body_length
nonisolated enum YouTubePlayerScripts {

    static let pipMessageHandlerName = "ytPiP"

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

    /// Event-driven autoplay helper. Native code calls `__yt.armAutoplay(ms)`
    /// after an action that should start the next item (e.g. skipping an ad).
    /// Once armed, any `<video>` becoming ready (`canplay` / `loadeddata` /
    /// `loadedmetadata` / `playing`) is played immediately. A long fallback
    /// poll covers the case where no event fires before the arm window expires.
    ///
    /// This replaces a short inline poll that gave up before the next ad or
    /// the main video had time to load.
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

    /// Bridges system Now Playing play/pause taps (Lock Screen, Control Center,
    /// PiP overlay, headset clicker) to the `__yt.userPaused` flag so the pause
    /// guard knows the pause was user-initiated and shouldn't be auto-resumed.
    static let mediaSessionUserActionBridge = """
    (function() {
        if (!('mediaSession' in navigator)) return;
        var ms = navigator.mediaSession;
        var origSet = ms.setActionHandler.bind(ms);
        var pageHandlers = { play: null, pause: null };

        function wrapper(action) {
            return function() {
                if (action === 'pause') {
                    window.__yt.userPaused = true;
                } else {
                    window.__yt.userPaused = false;
                    window.__yt.autoplayBlocked = false;
                    window.__yt.exitedPiPRecently = false;
                }
                var h = pageHandlers[action];
                if (typeof h === 'function') {
                    try { h(); return; } catch (e) {}
                }
                var v = document.querySelector('video');
                if (!v) return;
                if (action === 'pause') {
                    v.pause();
                } else {
                    var p = v.play();
                    if (p && typeof p.catch === 'function') p.catch(function(){});
                }
            };
        }

        function install(action) {
            try { origSet(action, wrapper(action)); } catch (e) {}
        }

        ms.setActionHandler = function(action, handler) {
            if (action === 'play' || action === 'pause') {
                pageHandlers[action] = handler || null;
                install(action);
                return;
            }
            return origSet(action, handler);
        };

        install('play');
        install('pause');
    })();
    """

    /// Re-routes the system next/previous track controls during ads so
    /// next-track invisibly skips the ad. Skips via `<video>.currentTime`
    /// so it does not depend on the click being a trusted gesture.
    static let pipAdControls = """
    (function() {
        if (!('mediaSession' in navigator)) return;
        var ms = navigator.mediaSession;
        var origSet = ms.setActionHandler.bind(ms);
        var MANAGED = {
            previoustrack: 1, nexttrack: 1,
            seekbackward: 1, seekforward: 1
        };
        var stored = {
            previoustrack: null, nexttrack: null,
            seekbackward: null, seekforward: null
        };
        var lastApplied = {
            previoustrack: undefined, nexttrack: undefined,
            seekbackward: undefined, seekforward: undefined
        };

        ms.setActionHandler = function(action, handler) {
            if (MANAGED[action]) {
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

        function isShowingAd() {
            var p = document.querySelector('.html5-video-player');
            return !!(p && p.classList.contains('ad-showing'));
        }

        function clickSkipButton(btn) {
            if (!btn) return;
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

        function seekAdToEnd() {
            var v = document.querySelector('video');
            if (!isShowingAd()) return false;
            if (!v || !isFinite(v.duration) || v.duration <= 0) return false;
            v.currentTime = Math.max(v.duration - 0.05, v.currentTime);
            return true;
        }

        function resumePlayback() {
            if (window.__yt && typeof window.__yt.armAutoplay === 'function') {
                window.__yt.armAutoplay(12000);
                return;
            }
            window.__yt.autoplayBlocked = false;
            window.__yt.userPaused = false;
            window.__yt.exitedPiPRecently = false;
        }

        function performSkipAd() {
            if (!isShowingAd()) return;
            var btn = findSkipButton();
            if (btn) {
                clickSkipButton(btn);
                seekAdToEnd();
                resumePlayback();
                return;
            }
            var attempts = 0;
            (function tick() {
                if (!isShowingAd()) { resumePlayback(); return; }
                var b = findSkipButton();
                if (b) {
                    clickSkipButton(b);
                    seekAdToEnd();
                    resumePlayback();
                    return;
                }
                if (++attempts < 24) {
                    setTimeout(tick, 250);
                } else {
                    seekAdToEnd();
                    resumePlayback();
                }
            })();
        }

        function apply() {
            var isAd = isShowingAd();

            var desired;
            if (isAd) {
                // Null out seek handlers so iOS shows previous/next-track
                // controls (mapped to skip-ad) instead of seek controls.
                desired = {
                    previoustrack: null,
                    nexttrack: performSkipAd,
                    seekbackward: null,
                    seekforward: null
                };
            } else {
                desired = {
                    previoustrack: stored.previoustrack,
                    nexttrack: stored.nexttrack,
                    seekbackward: stored.seekbackward,
                    seekforward: stored.seekforward
                };
            }

            Object.keys(desired).forEach(function(action) {
                if (lastApplied[action] !== desired[action]) {
                    try { origSet(action, desired[action]); } catch (e) {}
                    lastApplied[action] = desired[action];
                }
            });
        }

        setInterval(apply, 500);
        var classObserver = new MutationObserver(apply);
        function watchPlayer() {
            var p = document.querySelector('.html5-video-player');
            if (p && !p.__ytAdControlsObserved) {
                p.__ytAdControlsObserved = true;
                classObserver.observe(p, {
                    attributes: true, attributeFilter: ['class']
                });
            }
        }
        watchPlayer();
        var rootObserver = new MutationObserver(watchPlayer);
        if (document.documentElement) {
            rootObserver.observe(document.documentElement,
                { childList: true, subtree: true });
        }
        apply();
    })();
    """

    /// Forwards PiP enter/leave events to native code immediately. Uses the
    /// saved `addEventListener` from the isolation bootstrap so listeners are
    /// not filtered by the page-side block on PiP events.
    ///
    /// On iOS WKWebView the W3C `enterpictureinpicture`/`leavepictureinpicture`
    /// events are unreliable, the canonical signal is `webkitpresentationmodechanged`,
    /// read via `video.webkitPresentationMode`.
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
            window.__yt.addListener(video, 'enterpictureinpicture',
                function() { send('enter'); });
            window.__yt.addListener(video, 'leavepictureinpicture',
                function() { send('leave'); });
            window.__yt.addListener(video, 'webkitpresentationmodechanged',
                function() {
                    var nowInPiP =
                        video.webkitPresentationMode === 'picture-in-picture';
                    if (!nowInPiP && !window.__yt.expectingPiPExit) {
                        window.__yt.exitedPiPRecently = true;
                    }
                    window.__yt.expectingPiPExit = false;
                    send(nowInPiP ? 'enter' : 'leave');
                });
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
