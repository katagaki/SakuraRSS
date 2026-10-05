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
        try {
            // An explicit state creates a second WebKit platform session that can
            // interrupt the video. Keep native video state authoritative in every mode.
            descriptor.set.call(mediaSession, 'none');
            Object.defineProperty(mediaSession, 'playbackState', {
                configurable: true,
                enumerable: descriptor.enumerable,
                get: function() { return descriptor.get.call(mediaSession); },
                set: function() {}
            });
        } catch (error) {
            window.__yt.log('mediaSession playbackState override unavailable');
        }
    })();
    """
}
