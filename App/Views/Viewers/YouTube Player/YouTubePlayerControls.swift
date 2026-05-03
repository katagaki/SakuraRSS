import SwiftUI

struct YouTubePlayerControls: View {

    let isPlaying: Bool
    let isAd: Bool
    let isAdSkippable: Bool
    let onTogglePiP: () -> Void
    let onRewind: () -> Void
    let onTogglePlayPause: () -> Void
    let onSkipAd: () -> Void
    let onFastForward: () -> Void
    let onEnterFullscreen: () -> Void

    var body: some View {
        HStack(spacing: 32) {
            Button {
                onTogglePiP()
            } label: {
                Image(systemName: "pip.enter")
                    .font(.system(size: 22))
            }
            #if os(visionOS)
            .disabled(true)
            .opacity(0)
            #else
            .disabled(isAd)
            .opacity(isAd ? 0.5 : 1.0)
            #endif

            Spacer(minLength: 0)

            Button {
                onRewind()
            } label: {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 22))
            }
            .disabled(isAd)
            .opacity(isAd ? 0.5 : 1.0)

            Button {
                onTogglePlayPause()
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 62))
            }

            Button {
                if isAd && isAdSkippable {
                    onSkipAd()
                } else {
                    onFastForward()
                }
            } label: {
                Image(systemName: isAd
                    ? "forward.end.fill"
                    : "goforward.10")
                    .font(.system(size: 22))
                    .contentTransition(.symbolEffect(.replace))
            }
            .disabled(isAd && !isAdSkippable)
            .opacity((isAd && !isAdSkippable) ? 0.5 : 1.0)

            Spacer(minLength: 0)

            Button {
                onEnterFullscreen()
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 22))
            }
            .disabled(isAd)
            .opacity(isAd ? 0.5 : 1.0)
        }
        .foregroundStyle(.primary)
        #if os(visionOS)
        .buttonStyle(.plain)
        #endif
    }
}
