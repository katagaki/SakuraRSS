import MediaPlayer
import SwiftUI

extension AudioPlayer {

    // MARK: - Now Playing Info

    func postNowPlayingUpdate() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: currentEpisodeTitle ?? "",
            MPMediaItemPropertyArtist: currentFeedTitle ?? "",
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        if let cachedArtwork {
            info[MPMediaItemPropertyArtwork] = cachedArtwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func updateNowPlayingElapsedTime(_ time: TimeInterval) {
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[
            MPNowPlayingInfoPropertyElapsedPlaybackTime
        ] = time
    }

    func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Artwork Loading

    func loadArtwork(from urlString: String?) {
        guard let urlString, let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = UIImage(data: data), let cgImage = image.cgImage else { return }
            let safeImage = UIImage(cgImage: cgImage)
            let size = safeImage.size
            let artwork = MPMediaItemArtwork(boundsSize: size) { _ in safeImage }
            DispatchQueue.main.async {
                self?.cachedArtwork = artwork
                self?.postNowPlayingUpdate()
            }
        }.resume()
    }
}
