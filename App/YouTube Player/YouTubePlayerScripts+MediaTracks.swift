import Foundation
import Hanami

extension YouTubePlayerScripts {

    /// Reads the available caption tracks from the watch page's internal
    /// player (`#movie_player`). Returns `{ captions: [{code, name, selected}] }`,
    /// or an empty list when the captions module isn't ready yet.
    static let extractMediaTracks = """
    (function() {
        var player = document.querySelector('#movie_player')
            || document.querySelector('.html5-video-player');
        var result = { captions: [] };
        if (!player) { return result; }

        function nameFrom(value) {
            if (!value) { return ''; }
            if (typeof value === 'string') { return value; }
            if (typeof value.simpleText === 'string') { return value.simpleText; }
            if (value.runs && value.runs.length) {
                return value.runs.map(function(run) { return run.text || ''; }).join('');
            }
            return '';
        }

        try {
            if (typeof player.getOption === 'function') {
                var captionList = player.getOption('captions', 'tracklist') || [];
                var currentCaption = player.getOption('captions', 'track');
                var currentCode = (currentCaption && currentCaption.languageCode)
                    ? currentCaption.languageCode : '';
                result.captions = captionList.map(function(track) {
                    var name = nameFrom(track.displayName)
                        || nameFrom(track.languageName)
                        || track.languageCode || '';
                    return {
                        code: track.languageCode || '',
                        name: name,
                        selected: currentCode !== '' && track.languageCode === currentCode
                    };
                });
            }
        } catch (error) {}

        return result;
    })();
    """

    /// Switches the MSE player to the original (non-dubbed) audio track.
    /// Returns one of: `"switched"` (changed to original), `"original"`
    /// (already playing it), `"none"` (no original / single-audio video, so
    /// nothing to do), or `"pending"` (the track list hasn't populated yet —
    /// the Swift caller retries). Only works on the MSE player, where
    /// `getAvailableAudioTracks()` is populated.
    static let forceOriginalAudioTrack = """
    (function() {
        var player = document.querySelector('#movie_player')
            || document.querySelector('.html5-video-player');
        if (!player || typeof player.getAvailableAudioTracks !== 'function'
            || typeof player.setAudioTrack !== 'function') { return 'none'; }
        var tracks = player.getAvailableAudioTracks() || [];
        if (tracks.length === 0) { return 'pending'; }
        function info(track) {
            try { return track.getLanguageInfo(); } catch (error) { return null; }
        }
        var original = null;
        for (var i = 0; i < tracks.length; i++) {
            var detail = info(tracks[i]);
            if (detail && detail.isAutoDubbed === false) { original = tracks[i]; break; }
        }
        if (!original) { return 'none'; }
        var currentInfo = (typeof player.getAudioTrack === 'function')
            ? info(player.getAudioTrack()) : null;
        var originalInfo = info(original);
        if (currentInfo && originalInfo && currentInfo.id === originalInfo.id) {
            return 'original';
        }
        player.setAudioTrack(original);
        return 'switched';
    })();
    """

    /// Selects the caption track for `code`, or turns captions off when `code`
    /// is empty. `code` is JSON-encoded by the caller for safe interpolation.
    static func setCaptionTrack(encodedCode: String) -> String {
        """
        (function() {
            var player = document.querySelector('#movie_player')
                || document.querySelector('.html5-video-player');
            if (!player || typeof player.setOption !== 'function') { return false; }
            var code = \(encodedCode);
            if (code === '') {
                if (typeof player.unloadModule === 'function') {
                    player.unloadModule('captions');
                } else {
                    player.setOption('captions', 'track', {});
                }
                return true;
            }
            if (typeof player.loadModule === 'function') {
                player.loadModule('captions');
            }
            player.setOption('captions', 'track', { languageCode: code });
            player.setOption('captions', 'reload', true);
            return true;
        })();
        """
    }
}
