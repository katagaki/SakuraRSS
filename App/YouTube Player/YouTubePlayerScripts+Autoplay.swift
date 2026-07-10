import Foundation
import Hanami

extension YouTubePlayerScripts {

    /// Plays the next ready `<video>` after `__yt.armAutoplay(ms)` is called.
    /// Calls both `playVideo()` and `<video>.play()` every attempt instead of
    /// picking one: `#movie_player.playVideo` can exist before the player is
    /// actually wired up, so treating its presence as "handled" would swallow
    /// the attempt with nothing to fall back on.
    static let autoplayArmer = """
    (function() {
        if (!window.__yt) return;
        if (window.__yt.armAutoplay) return;
        window.__yt.autoplayArmedUntil = 0;

        function armed() {
            return Date.now() < (window.__yt.autoplayArmedUntil || 0);
        }

        function mediaMissing(video) {
            return video.readyState === 0 && !video.currentSrc && !video.srcObject;
        }
        window.__yt.mediaMissing = mediaMissing;

        var PLAYER_ENDED = 0;
        var PLAYER_PLAYING = 1;
        var PLAYER_BUFFERING = 3;

        function playViaPlayerAPI() {
            var player = document.getElementById('movie_player');
            if (!player || typeof player.playVideo !== 'function') return;
            var state = -1;
            try {
                if (typeof player.getPlayerState === 'function') {
                    state = player.getPlayerState();
                }
            } catch (e) {}
            if (state === PLAYER_ENDED || state === PLAYER_PLAYING
                || state === PLAYER_BUFFERING) return;
            try { player.playVideo(); } catch (e) {}
        }

        function suppressed() {
            return window.__yt.userPaused === true
                || window.__yt.autoplayBlocked === true
                || window.__yt.exitedPiPRecently === true;
        }

        function tryPlay(video) {
            if (suppressed()) return;
            if (video && video.ended) return;
            if (video && !video.paused && !mediaMissing(video)) return;
            playViaPlayerAPI();
            if (!video) return;
            try {
                if (!video.paused && mediaMissing(video)) {
                    var now = Date.now();
                    if (now - (video.__ytLastPlayCycle || 0) < 1000) return;
                    video.__ytLastPlayCycle = now;
                    video.pause();
                }
                var playPromise = video.play();
                if (playPromise && typeof playPromise.catch === 'function') {
                    playPromise.catch(function(){});
                }
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
                var videos = document.querySelectorAll('video');
                if (videos.length > 0) {
                    videos.forEach(tryPlay);
                } else {
                    tryPlay(null);
                }
                setTimeout(tick, 200);
            })();
        };
    })();
    """

    /// One native-initiated play attempt, evaluated repeatedly by the
    /// coordinator until it returns `done` or `suppressed`. Must run through
    /// `evaluateJavaScript` rather than a user script: WebKit gives that call
    /// a synthetic user gesture, which the mobile watch page requires before
    /// it will attach media — a `WKUserScript` timer loop never gets one.
    static let nativeAutoplayKick = """
    (function() {
        if (!window.__yt) return 'waiting';
        if (window.__yt.userPaused === true) return 'suppressed';
        if (window.__yt.autoplayBlocked === true) return 'suppressed';
        var video = document.querySelector('video');
        if (!video) return 'waiting';
        if (video.ended) return 'done';
        var mediaMissing = (typeof window.__yt.mediaMissing === 'function')
            ? window.__yt.mediaMissing(video)
            : (video.readyState === 0 && !video.currentSrc && !video.srcObject);
        if (!video.paused && !mediaMissing) return 'done';
        window.__yt.exitedPiPRecently = false;
        if (!video.paused) { video.pause(); }
        var playPromise = video.play();
        if (playPromise && typeof playPromise.catch === 'function') {
            playPromise.catch(function(){});
        }
        return 'kicked';
    })();
    """

    /// Arms autoplay at document end so the first video plays as soon as its
    /// media is ready instead of waiting for YouTube's own autoplay, which
    /// only fires after the whole watch page finishes initializing. Unmutes on
    /// the first `playing` because this can start playback before `didFinish`,
    /// where the coordinator's unmute normally runs.
    ///
    /// Keeps re-arming past the first window because the mobile watch page
    /// can finish wiring its lazy media attach after the initial 15 seconds,
    /// leaving the player unstarted with nothing left to retry.
    static let initialAutoplayKick = """
    (function() {
        if (!window.__yt || typeof window.__yt.armAutoplay !== 'function') return;
        window.__yt.armAutoplay(15000);
        var rearmDeadline = Date.now() + 90000;
        function playbackStarted() {
            var videos = document.querySelectorAll('video');
            for (var index = 0; index < videos.length; index++) {
                if (videos[index].currentTime > 0) return true;
            }
            return false;
        }
        function rearmUntilStarted() {
            if (Date.now() > rearmDeadline) return;
            if (playbackStarted()) return;
            if (window.__yt.userPaused === true) return;
            if (window.__yt.autoplayBlocked === true) return;
            window.__yt.armAutoplay(6000);
            setTimeout(rearmUntilStarted, 5000);
        }
        setTimeout(rearmUntilStarted, 15000);
        function unmute(video) {
            if (video.muted) { video.muted = false; }
            var player = document.getElementById('movie_player');
            if (player && typeof player.unMute === 'function') {
                player.unMute();
                if (typeof player.setVolume === 'function'
                    && typeof player.getVolume === 'function'
                    && player.getVolume() === 0) {
                    player.setVolume(100);
                }
            }
        }
        function attach(video) {
            if (!video || video.__ytInitialUnmuteAttached) return;
            video.__ytInitialUnmuteAttached = true;
            window.__yt.addListener(video, 'playing', function() {
                unmute(video);
            }, true);
        }
        function scan() { document.querySelectorAll('video').forEach(attach); }
        scan();
        var observer = new MutationObserver(scan);
        if (document.documentElement) {
            observer.observe(document.documentElement,
                { childList: true, subtree: true });
            setTimeout(function() { observer.disconnect(); }, 20000);
        }
    })();
    """
}
