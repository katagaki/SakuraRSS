import Foundation
import Hanami

extension YouTubePlayerScripts {

    /// Plays the next ready `<video>` after `__yt.armAutoplay(ms)` is called.
    ///
    /// The mobile watch page (m.youtube.com) ships its `<video>` with no media
    /// attached and only attaches a source in reaction to a fresh `play`
    /// event. A `play()` that ran before the page's listener existed flips
    /// `paused` to false with no media and no further `play` event can fire,
    /// so `tryPlay` cycles `pause()` first to make the retry observable.
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

        function tryPlay(video) {
            if (!video || video.ended) return;
            if (!video.paused && !mediaMissing(video)) return;
            if (window.__yt.userPaused === true) return;
            if (window.__yt.autoplayBlocked === true) return;
            if (window.__yt.exitedPiPRecently === true) return;
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
                document.querySelectorAll('video').forEach(tryPlay);
                setTimeout(tick, 200);
            })();
        };
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
