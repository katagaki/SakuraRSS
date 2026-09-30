import Foundation

extension YouTubePlayerScripts {
    static let playbackOwnership = """
    (function() {
        var state = window.__yt;
        if (!state) return;
        var originalPause = HTMLMediaElement.prototype.pause;
        var originalPlay = HTMLMediaElement.prototype.play;
        var pagePauses = new WeakSet();
        var loggedPauses = new WeakSet();
        var synchronizing = new WeakSet();
        function managed(video) {
            return video instanceof HTMLVideoElement && video === state.getPlaybackVideo();
        }
        function protectedPlayback(video) {
            return managed(video) && (document.visibilityState !== 'visible' || state.isInPiP());
        }
        HTMLMediaElement.prototype.pause = function() {
            if (protectedPlayback(this) && !state.userPaused && !state.autoplayBlocked
                && !state.exitedPiPRecently && !this.ended && this.readyState > 0) {
                if (!loggedPauses.has(this)) {
                    loggedPauses.add(this);
                    state.logState('blocked page pause during background/PiP playback', this);
                }
                if (!this.paused) synchronizePlayer(this, false);
                return;
            }
            if (!this.paused) pagePauses.add(this);
            return originalPause.call(this);
        };
        HTMLMediaElement.prototype.play = function() {
            if (managed(this) && (state.userPaused || state.autoplayBlocked || state.exitedPiPRecently)) {
                return Promise.reject(new DOMException('Playback was paused by the user', 'AbortError'));
            }
            return originalPlay.call(this);
        };
        function synchronizePlayer(video, paused) {
            if (synchronizing.has(video)) return;
            var player = document.getElementById('movie_player');
            if (!player || typeof player.getPlayerState !== 'function') return;
            synchronizing.add(video);
            try {
                var playerState = player.getPlayerState();
                if (paused && playerState !== 2 && typeof player.pauseVideo === 'function') {
                    player.pauseVideo();
                } else if (!paused && playerState !== 1 && playerState !== 3
                    && typeof player.playVideo === 'function') {
                    player.playVideo();
                }
            } catch (error) {
                state.logState('native playback synchronization failed', video);
            } finally {
                synchronizing.delete(video);
            }
        }
        // Capture native intent before YouTube's target listeners reconcile stale player state.
        document.addEventListener('play', function(event) {
            var video = event.target;
            if (!managed(video) || video.paused) return;
            pagePauses.delete(video);
            state.userPaused = false;
            state.exitedPiPRecently = false;
            loggedPauses.delete(video);
            state.logState('native video play', video);
            synchronizePlayer(video, false);
        }, true);
        document.addEventListener('pause', function(event) {
            var video = event.target;
            if (!managed(video)) return;
            var pagePause = pagePauses.delete(video);
            if (!video.paused || video.ended || video.readyState === 0 || pagePause) return;
            state.userPaused = true;
            state.logState('native video pause', video);
            synchronizePlayer(video, true);
        }, true);

        var originalPresentationMode = HTMLVideoElement.prototype.webkitSetPresentationMode;
        var originalRequestPiP = HTMLVideoElement.prototype.requestPictureInPicture;
        var originalExitPiP = Document.prototype.exitPictureInPicture;
        if (originalPresentationMode) {
            HTMLVideoElement.prototype.webkitSetPresentationMode = function(mode) {
                if (managed(this) && (mode === 'picture-in-picture' || state.isInPiP())) {
                    state.logState('blocked page presentation change ' + mode, this);
                    return;
                }
                return originalPresentationMode.call(this, mode);
            };
        }
        if (originalRequestPiP) {
            HTMLVideoElement.prototype.requestPictureInPicture = function() {
                if (managed(this)) {
                    return Promise.reject(new DOMException('Use native PiP controls', 'NotAllowedError'));
                }
                return originalRequestPiP.call(this);
            };
        }
        if (originalExitPiP) {
            Document.prototype.exitPictureInPicture = function() {
                if (state.isInPiP()) {
                    return Promise.reject(new DOMException('Use native PiP controls', 'NotAllowedError'));
                }
                return originalExitPiP.call(this);
            };
        }
        var observedVideos = new WeakSet();
        state.onMutation(function() {
            var video = state.getPlaybackVideo();
            if (!video || observedVideos.has(video)) return;
            observedVideos.add(video);
            try {
                Object.defineProperty(video, 'disablePictureInPicture', {
                    configurable: true,
                    get: function() { return false; },
                    set: function() {}
                });
            } catch (error) {}
            function allowPiP() {
                if (video.hasAttribute('disablepictureinpicture')) video.removeAttribute('disablepictureinpicture');
            }
            allowPiP();
            new MutationObserver(allowPiP).observe(video, {
                attributes: true, attributeFilter: ['disablepictureinpicture']
            });
        });
    })();
    """
}
