import SwiftUI
import AVFoundation
import Combine

/// Inline audio player for `{{AUDIO}}` markers with a compact control row
/// matching the YouTube embed style.
struct AudioBlockView: View {

    let url: URL

    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var duration: TimeInterval = 0
    @State private var statusObserver: AnyCancellable?
    @State private var endObserver: AnyCancellable?

    private func currentTime() -> TimeInterval {
        guard let player else { return 0 }
        let seconds = player.currentTime().seconds
        return seconds.isFinite ? seconds : 0
    }

    var body: some View {
        controls
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.thinMaterial)
            .clipShape(.rect(cornerRadius: 12))
            .onAppear(perform: setupPlayer)
            .onDisappear(perform: teardownPlayer)
    }

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 12) {
            Button(action: togglePlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.callout)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            Button {
                seek(by: -10)
            } label: {
                Image(systemName: "gobackward.10")
                    .font(.callout)
            }
            .buttonStyle(.plain)

            Button {
                seek(by: 10)
            } label: {
                Image(systemName: "goforward.10")
                    .font(.callout)
            }
            .buttonStyle(.plain)

            TimelineView(.periodic(from: .now, by: 1.0)) { _ in
                Text(timeLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .foregroundStyle(.primary)
    }

    private var timeLabel: String {
        let current = Int(max(0, currentTime()))
        let total = Int(max(0, duration))
        return "\(formatTime(current)) / \(formatTime(total))"
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remaining = seconds % 60
        return String(format: "%d:%02d", minutes, remaining)
    }

    private func setupPlayer() {
        let player = AVPlayer(url: url)
        self.player = player

        statusObserver = player.publisher(for: \.currentItem?.duration)
            .receive(on: DispatchQueue.main)
            .sink { newDuration in
                if let newDuration, newDuration.isNumeric {
                    duration = newDuration.seconds
                }
            }

        endObserver = NotificationCenter.default
            .publisher(for: AVPlayerItem.didPlayToEndTimeNotification)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                isPlaying = false
                player.seek(to: .zero)
            }
    }

    private func teardownPlayer() {
        statusObserver?.cancel()
        statusObserver = nil
        endObserver?.cancel()
        endObserver = nil
        player?.pause()
        player = nil
        isPlaying = false
    }

    private func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try? AVAudioSession.sharedInstance().setActive(true)
            player.play()
        }
        isPlaying.toggle()
    }

    private func seek(by delta: TimeInterval) {
        guard let player else { return }
        let target = max(0, min(duration, currentTime() + delta))
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
    }
}
