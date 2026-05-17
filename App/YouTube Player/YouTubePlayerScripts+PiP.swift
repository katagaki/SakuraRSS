import Foundation
import Hanami

extension YouTubePlayerScripts {

    /// Re-routes the system next/previous track controls during ads.
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
            // Arm autoplay before the skip so the post-ad video swap plays
            // without the usual startup delay.
            resumePlayback();
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

        // No-op handler; setting `null` would let the user agent fall back
        // to its default seek behavior.
        function blockRewind() {}

        function apply() {
            var isAd = isShowingAd();

            var desired;
            if (isAd) {
                desired = {
                    previoustrack: blockRewind,
                    nexttrack: performSkipAd,
                    seekbackward: blockRewind,
                    seekforward: performSkipAd
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

    // Adapted from Brave's auto-PiP target selection.
    static let autoPipTargetBridge = """
    (function() {
        if (!('mediaSession' in navigator)) return;

        function pickAutoPipTarget() {
            var videos = document.getElementsByTagName('video');
            var bestPlaying = null;
            var bestPlayingArea = 0;
            var bestReady = null;
            var bestReadyArea = 0;
            for (var index = 0; index < videos.length; index++) {
                var video = videos[index];
                if (video.disablePictureInPicture) continue;
                var rect = video.getBoundingClientRect();
                var width = Math.max(0, rect.width);
                var height = Math.max(0, rect.height);
                var area = width * height;
                if (area <= 0) continue;
                if (!video.paused && !video.ended
                    && video.readyState >= 2
                    && area > bestPlayingArea) {
                    bestPlaying = video;
                    bestPlayingArea = area;
                }
                if (video.readyState >= 1 && area > bestReadyArea) {
                    bestReady = video;
                    bestReadyArea = area;
                }
            }
            return bestPlaying || bestReady;
        }

        try {
            navigator.mediaSession.setActionHandler('enterpictureinpicture',
                function() {
                    var video = pickAutoPipTarget();
                    if (!video) return;
                    if (window.__yt
                        && typeof window.__yt.enterPiP === 'function') {
                        window.__yt.enterPiP(video);
                    }
                });
        } catch (error) {}
    })();
    """
}
