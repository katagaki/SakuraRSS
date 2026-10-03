import Foundation

nonisolated enum YouTubePlayerScripts {
    static let pipMessageHandlerName = "ytPiP"
    static let playbackMessageHandlerName = "ytPlayback"

    static let mediaIsolationBootstrap = """
    (function() {
        if (window.__yt) return;
        var originalPlay = HTMLMediaElement.prototype.play;
        var originalPause = HTMLMediaElement.prototype.pause;
        var originalRequestPiP = HTMLVideoElement.prototype.requestPictureInPicture;
        var originalExitPiP = Document.prototype.exitPictureInPicture;
        var originalPresentationMode = HTMLVideoElement.prototype.webkitSetPresentationMode;
        function propertyGetter(target, name) {
            while (target) {
                var descriptor = Object.getOwnPropertyDescriptor(target, name);
                if (descriptor) return descriptor.get || null;
                target = Object.getPrototypeOf(target);
            }
            return null;
        }
        var visibilityGetter = propertyGetter(document, 'visibilityState');
        var presentationGetter = propertyGetter(HTMLVideoElement.prototype, 'webkitPresentationMode');
        var pipElementGetter = propertyGetter(document, 'pictureInPictureElement');
        window.__yt = {
            autoplayBlocked: false,
            userPaused: false,
            exitedPiPRecently: false,
            expectingPiPExit: false,
            addListener: function(target, type, listener, options) {
                target.addEventListener(type, listener, options);
            },
            removeListener: function(target, type, listener, options) {
                target.removeEventListener(type, listener, options);
            },
            realVisibilityState: function() {
                return visibilityGetter ? visibilityGetter.call(document) : document.visibilityState;
            },
            realPresentationMode: function(video) {
                return presentationGetter ? presentationGetter.call(video) : video.webkitPresentationMode;
            },
            realPiPElement: function() {
                return pipElementGetter ? pipElementGetter.call(document) : document.pictureInPictureElement;
            },
            resumeVideo: function(video) { return originalPlay.call(video); },
            pauseVideo: function(video) { return originalPause.call(video); },
            logState: function() {},
            getPiPVideo: function() {
                return Array.from(document.querySelectorAll('video')).find(function(video) {
                    return window.__yt.realPresentationMode(video) === 'picture-in-picture'
                        || window.__yt.realPiPElement() === video;
                }) || null;
            },
            getPlaybackVideo: function() {
                return this.getPiPVideo() || document.querySelector('#movie_player video')
                    || document.querySelector('video');
            },
            isInPiP: function() { return !!this.getPiPVideo(); },
            enterPiP: function(video) {
                if (!video) return;
                this.logState('native enterPiP()', video);
                if (originalPresentationMode) {
                    originalPresentationMode.call(video, 'picture-in-picture');
                } else if (originalRequestPiP) {
                    originalRequestPiP.call(video).catch(function() {});
                }
            },
            exitPiP: function(video) {
                this.logState('native exitPiP()', video);
                if (video && originalPresentationMode) {
                    originalPresentationMode.call(video, 'inline');
                } else if (this.realPiPElement() && originalExitPiP) {
                    originalExitPiP.call(document).catch(function() {});
                }
            },
            log: function(message) {
                try {
                    window.webkit.messageHandlers.ytDebug.postMessage(message);
                } catch (error) {}
            }
        };
        var mutationCallbacks = [];
        var mutationPending = false;
        var mutationLastRun = 0;
        function runMutationCallbacks() {
            mutationPending = false;
            mutationLastRun = Date.now();
            for (var index = 0; index < mutationCallbacks.length; index++) {
                try { mutationCallbacks[index](); } catch (error) {}
            }
        }
        window.__yt.onMutation = function(callback) {
            mutationCallbacks.push(callback);
            try { callback(); } catch (error) {}
        };
        function containsPlayer(node) {
            return node.nodeType === 1 && (node.matches('video, .html5-video-player')
                || node.querySelector('video, .html5-video-player'));
        }
        var sharedMutationObserver = new MutationObserver(function(records) {
            var changed = records.some(function(record) {
                return Array.from(record.addedNodes).some(containsPlayer)
                    || Array.from(record.removedNodes).some(containsPlayer);
            });
            if (!changed) return;
            if (mutationPending) return;
            var elapsed = Date.now() - mutationLastRun;
            if (elapsed >= 250) {
                runMutationCallbacks();
            } else {
                mutationPending = true;
                setTimeout(runMutationCallbacks, 250 - elapsed);
            }
        });
        sharedMutationObserver.observe(document, { childList: true, subtree: true });

    })();
    """
}
