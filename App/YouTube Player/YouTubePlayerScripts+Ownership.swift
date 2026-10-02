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
        var wrappedPlayers = new WeakSet();
        var pendingResumes = new WeakMap();
        function managed(video) {
            return video instanceof HTMLVideoElement && video === state.getPlaybackVideo();
        }
        function protectedPlayback(video) {
            return managed(video) && (document.visibilityState !== 'visible' || state.isInPiP());
        }
        function blockPagePause(video) {
            if (!protectedPlayback(video) || video.paused || video.ended) return false;
            if (state.isInPiP()) return true;
            return !state.userPaused && !state.autoplayBlocked
                && !state.exitedPiPRecently && video.readyState > 0;
        }
        HTMLMediaElement.prototype.pause = function() {
            if (blockPagePause(this)) {
                if (!loggedPauses.has(this)) {
                    loggedPauses.add(this);
                    state.logState('blocked page pause during background/PiP playback', this);
                }
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
        function protectPlayer() {
            var player = document.getElementById('movie_player');
            if (!player || wrappedPlayers.has(player) || typeof player.pauseVideo !== 'function') return;
            var originalPauseVideo = player.pauseVideo;
            var guardedPauseVideo = function() {
                var video = state.getPlaybackVideo();
                if (video && blockPagePause(video)) {
                    state.logState('blocked page player pause during background/PiP playback', video);
                    return;
                }
                return originalPauseVideo.apply(this, arguments);
            };
            try {
                Object.defineProperty(player, 'pauseVideo', {
                    configurable: true,
                    get: function() { return guardedPauseVideo; },
                    set: function(handler) {
                        if (typeof handler === 'function' && handler !== guardedPauseVideo) {
                            originalPauseVideo = handler;
                        }
                    }
                });
            } catch (error) {
                player.pauseVideo = guardedPauseVideo;
            }
            wrappedPlayers.add(player);
        }
        function synchronizeResume(video) {
            if (!state.isInPiP() || pendingResumes.has(video)) return;
            var timeout = setTimeout(function() { finishResume(video); }, 750);
            pendingResumes.set(video, timeout);
        }
        function finishResume(video) {
            if (!pendingResumes.has(video)) return;
            clearTimeout(pendingResumes.get(video));
            pendingResumes.delete(video);
            Promise.resolve().then(function() {
                if (!managed(video) || !state.isInPiP() || video.paused || video.ended
                    || state.userPaused || state.autoplayBlocked || state.exitedPiPRecently) return;
                var player = document.getElementById('movie_player');
                if (!player || typeof player.getPlayerState !== 'function'
                    || typeof player.playVideo !== 'function') return;
                var playerState = player.getPlayerState();
                if (playerState === 1 || playerState === 3) return;
                state.logState('synchronize stream controller after native PiP resume', video);
                player.playVideo();
            }).catch(function() { state.logState('stream controller resume failed', video); });
        }
        window.addEventListener('play', function(event) {
            var video = event.target;
            if (!managed(video) || video.paused) return;
            protectPlayer();
            pagePauses.delete(video);
            state.userPaused = false;
            state.exitedPiPRecently = false;
            loggedPauses.delete(video);
            state.logState('unwrapped video play', video);
            synchronizeResume(video);
        }, true);
        window.addEventListener('playing', function(event) {
            if (managed(event.target)) finishResume(event.target);
        }, true);
        window.addEventListener('pause', function(event) {
            var video = event.target;
            if (!managed(video)) return;
            if (pendingResumes.has(video)) {
                clearTimeout(pendingResumes.get(video));
                pendingResumes.delete(video);
            }
            var pagePause = pagePauses.delete(video);
            if (!video.paused || video.ended || video.readyState === 0) return;
            if (pagePause) {
                state.logState('page video pause', video);
                return;
            }
            state.userPaused = true;
            state.logState('unwrapped video pause', video);
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
            protectPlayer();
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
