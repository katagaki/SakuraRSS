import Foundation
import Hanami

extension YouTubePlayerScripts {

    /// Switches the MSE player to the original (non-dubbed) audio track.
    /// Returns one of: `"switched"` (changed to original), `"original"`
    /// (already playing it), `"none"` (no original / single-audio video, so
    /// nothing to do), or `"pending"` (the player or its track list hasn't
    /// populated yet — the Swift caller retries). Only works on the MSE
    /// player, where `getAvailableAudioTracks()` is populated. The player and
    /// its audio-track methods can be absent for a moment after playback
    /// starts, so report that as `"pending"` rather than `"none"`; otherwise
    /// the auto-dub is never corrected on slower (mobile) loads.
    static let forceOriginalAudioTrack = """
    (function() {
        var player = document.querySelector('#movie_player')
            || document.querySelector('.html5-video-player');
        if (!player || typeof player.getAvailableAudioTracks !== 'function'
            || typeof player.setAudioTrack !== 'function') { return 'pending'; }
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
}
