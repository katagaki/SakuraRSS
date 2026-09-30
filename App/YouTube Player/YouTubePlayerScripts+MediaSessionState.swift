import Foundation

extension YouTubePlayerScripts {
    static let mediaSessionPlaybackStateBridge = """
    (function() {
        if (!window.__yt || !navigator.mediaSession) return;
        var mediaSession = navigator.mediaSession;
        var prototype = mediaSession;
        var descriptor;
        while (prototype && !descriptor) {
            descriptor = Object.getOwnPropertyDescriptor(prototype, 'playbackState');
            prototype = Object.getPrototypeOf(prototype);
        }
        if (!descriptor || !descriptor.get || !descriptor.set) return;
        var pageState = descriptor.get.call(mediaSession);

        function applyState() {
            var pipVideo = window.__yt.getPiPVideo();
            // WebKit gives explicit playbackState its own platform session. In PiP,
            // let the video own playback so that session cannot interrupt its resume.
            var nativeState = pipVideo ? 'none' : pageState;
            if (descriptor.get.call(mediaSession) === nativeState) return;
            descriptor.set.call(mediaSession, nativeState);
            window.__yt.logState('mediaSession state ' + pageState + ' -> ' + nativeState, pipVideo);
        }
        try {
            Object.defineProperty(mediaSession, 'playbackState', {
                configurable: true,
                enumerable: descriptor.enumerable,
                get: function() { return descriptor.get.call(mediaSession); },
                set: function(value) {
                    if (value !== 'none' && value !== 'paused' && value !== 'playing') {
                        descriptor.set.call(mediaSession, value);
                        return;
                    }
                    pageState = value;
                    applyState();
                }
            });
        } catch (error) {
            window.__yt.log('mediaSession playbackState override unavailable');
            return;
        }
        window.__yt.updatePiPMediaSessionState = applyState;
        ['enterpictureinpicture', 'leavepictureinpicture',
            'webkitpresentationmodechanged'].forEach(function(type) {
            document.addEventListener(type, applyState, true);
        });
        applyState();
    })();
    """
}
