import Foundation
import Hanami

extension YouTubePlayerScripts {

    /// Ad state is driven by a `MutationObserver` on the player's `class`.
    static let playbackEventBridge = """
    (function() {
        var lastTimeQuarter = -1;
        var lastAdSig = '';
        var lastIsAd = null;
        function send(payload) {
            try {
                window.webkit.messageHandlers.\(playbackMessageHandlerName)
                    .postMessage(payload);
            } catch (e) {}
        }
        // Re-emits current state. Used by the native side after re-attaching the
        // message handler to a WebView whose initial events already fired.
        window.__ytPrimePlayback = function() {
            var videos = document.querySelectorAll('video');
            for (var i = 0; i < videos.length; i++) {
                var v = videos[i];
                send({
                    event: v.paused ? 'pause' : 'play',
                    currentTime: v.currentTime,
                    duration: v.duration || 0,
                    rate: v.playbackRate
                });
                send({
                    event: 'meta',
                    videoWidth: v.videoWidth || 0,
                    videoHeight: v.videoHeight || 0,
                    duration: isFinite(v.duration) ? v.duration : 0
                });
            }
            sendAd(true);
        };
        function snapshotAd() {
            var p = document.querySelector('.html5-video-player');
            var isAd = !!(p && p.classList.contains('ad-showing'));
            var skipBtn = isAd ? \(findSkipButtonExpression) : null;
            var advLink = isAd ? document.querySelector(
                '.ytp-ad-visit-advertiser-button, .ytp-ad-button,'
                + ' a[class*="visit-advertiser"], .ytp-ad-overlay-link'
            ) : null;
            var advURL = advLink
                ? (advLink.href || advLink.getAttribute('href') || '') : '';
            return { isAd: isAd, adSkippable: !!skipBtn, advertiserURL: advURL };
        }
        function sendAd(force) {
            var s = snapshotAd();
            var sig = (s.isAd ? '1' : '0') + ':'
                + (s.adSkippable ? '1' : '0') + ':' + s.advertiserURL;
            if (!force && sig === lastAdSig) return;
            lastAdSig = sig;
            // YouTube swaps the <video> source during ad <> content
            // transitions, which leaves the element paused with no
            // pause event to retrigger the pause guard (and the guard's
            // end-of-video bail also fires when an ad ends naturally).
            // Arm the autoplay poller so it picks up the new media as
            // soon as it is ready. Respect `userPaused` so a manual
            // pause during an ad survives the natural ad end.
            if (lastIsAd !== null && lastIsAd !== s.isAd
                && window.__yt && window.__yt.userPaused !== true
                && typeof window.__yt.armAutoplay === 'function') {
                window.__yt.armAutoplay(8000);
            }
            lastIsAd = s.isAd;
            send({ event: 'ad', isAd: s.isAd,
                adSkippable: s.adSkippable, advertiserURL: s.advertiserURL });
        }
        function meta(video) {
            var w = video.videoWidth || 0;
            var h = video.videoHeight || 0;
            var d = isFinite(video.duration) ? video.duration : 0;
            send({ event: 'meta', videoWidth: w, videoHeight: h, duration: d });
        }
        function attachVideo(video) {
            if (!video || video.__ytPlaybackAttached) return;
            video.__ytPlaybackAttached = true;
            var add = window.__yt.addListener;
            add(video, 'play', function() {
                send({ event: 'play', currentTime: video.currentTime,
                    duration: video.duration || 0, rate: video.playbackRate });
            });
            add(video, 'playing', function() {
                send({ event: 'playing', currentTime: video.currentTime });
            });
            add(video, 'pause', function() {
                send({ event: 'pause', currentTime: video.currentTime });
            });
            add(video, 'waiting', function() { send({ event: 'buffering' }); });
            add(video, 'ended', function() { send({ event: 'ended' }); });
            add(video, 'seeked', function() {
                lastTimeQuarter = -1;
                send({ event: 'seek', currentTime: video.currentTime });
            });
            add(video, 'ratechange', function() {
                send({ event: 'rate', rate: video.playbackRate });
            });
            add(video, 'durationchange', function() {
                send({ event: 'duration', duration: video.duration || 0 });
            });
            add(video, 'loadedmetadata', function() { meta(video); });
            add(video, 'resize', function() { meta(video); });
            // `timeupdate` fires ~4 Hz while playing and not at all while
            // paused. We coalesce to quarter-second resolution so SponsorBlock
            // checks stay responsive without flooding SwiftUI.
            add(video, 'timeupdate', function() {
                var t = video.currentTime;
                var q = Math.floor(t * 4);
                if (q === lastTimeQuarter) return;
                lastTimeQuarter = q;
                send({ event: 'time', currentTime: t });
            });
            meta(video);
            send({ event: video.paused ? 'pause' : 'play',
                currentTime: video.currentTime,
                duration: video.duration || 0,
                rate: video.playbackRate });
        }
        function scan() {
            document.querySelectorAll('video').forEach(attachVideo);
        }
        scan();
        var videoObserver = new MutationObserver(scan);
        if (document.documentElement) {
            videoObserver.observe(document.documentElement,
                { childList: true, subtree: true });
        }
        function attachAdObserver() {
            var p = document.querySelector('.html5-video-player');
            if (!p || p.__ytAdSignalObserved) return;
            p.__ytAdSignalObserved = true;
            var obs = new MutationObserver(function() { sendAd(false); });
            obs.observe(p, { attributes: true, attributeFilter: ['class'] });
            // The skip button appears as a child after the ad-showing class
            // flips, so observe subtree mutations to refresh `adSkippable` and
            // the advertiser URL when the DOM updates.
            var sub = new MutationObserver(function() { sendAd(false); });
            sub.observe(p, { childList: true, subtree: true });
            sendAd(true);
        }
        attachAdObserver();
        var rootObserver = new MutationObserver(attachAdObserver);
        if (document.documentElement) {
            rootObserver.observe(document.documentElement,
                { childList: true, subtree: true });
        }
    })();
    """
}
