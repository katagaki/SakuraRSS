import Foundation
import Hanami

extension YouTubePlayerScripts {

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

    /// Temporary diagnostic: dumps what the player exposes about audio tracks
    /// so the iPhone-specific dub failure can be diagnosed from device logs.
    static let audioTrackDiagnostics = """
    (function() {
        function describe(track) {
            if (!track) { return null; }
            var info = null;
            try { info = (typeof track.getLanguageInfo === 'function') ? track.getLanguageInfo() : null; }
            catch (error) { info = { error: String(error) }; }
            return { id: track.id, info: info };
        }
        var player = document.querySelector('#movie_player')
            || document.querySelector('.html5-video-player');
        var out = {
            hasPlayer: !!player,
            hasGetTracks: !!player && typeof player.getAvailableAudioTracks === 'function',
            hasSetTrack: !!player && typeof player.setAudioTrack === 'function',
            hasGetTrack: !!player && typeof player.getAudioTrack === 'function',
            videoCount: document.querySelectorAll('video').length
        };
        if (out.hasGetTracks) {
            var tracks = [];
            try { tracks = player.getAvailableAudioTracks() || []; } catch (error) { out.tracksError = String(error); }
            out.trackCount = tracks.length;
            out.tracks = tracks.map(describe);
        }
        if (out.hasGetTrack) {
            try { out.current = describe(player.getAudioTrack()); } catch (error) { out.currentError = String(error); }
        }
        return JSON.stringify(out);
    })();
    """
}
