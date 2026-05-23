import SwiftUI
import Hanami

/// Liquid-Glass control overlay that sits on top of the video itself.
/// Tapping the video toggles visibility; an internal timer auto-hides
/// the controls a few seconds after the last interaction.
struct YouTubePlayerOverlayControls: View {

    let session: YouTubePlayerSession
    let isPlaying: Bool
    let isAd: Bool
    let isAdSkippable: Bool
    let videoAspectRatio: CGFloat
    let segments: [(start: Double, end: Double)]
    let onTogglePiP: () -> Void
    let onRewind: () -> Void
    let onTogglePlayPause: () -> Void
    let onSkipAd: () -> Void
    let onFastForward: () -> Void
    let onSeek: (TimeInterval) -> Void
    let onEnterFullscreen: () -> Void

    @State private var isVisible = true
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            if isVisible {
                Color.black.opacity(0.3)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            Color.clear
                .contentShape(.rect)
                .onTapGesture {
                    toggleVisibility()
                }

            if isVisible {
                CompatibleGlassEffectContainer {
                    VStack(spacing: 0) {
                        topBar
                        Spacer(minLength: 4)
                        centerControl
                        Spacer(minLength: 4)
                        bottomBar
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .foregroundStyle(.white)
                    .transition(.opacity)
                }
            }
        }
        .onAppear { scheduleAutoHide() }
        .onChange(of: isPlaying) { _, _ in scheduleAutoHide() }
    }

    @ViewBuilder
    private var topBar: some View {
        HStack {
            pictureInPictureButton
            Spacer()
            fullscreenButton
        }
    }

    @ViewBuilder
    private var pictureInPictureButton: some View {
        Button {
            onTogglePiP()
            scheduleAutoHide()
        } label: {
            Image(systemName: "pip.enter")
                .font(.system(size: 16, weight: .medium))
                .frame(width: 40, height: 40)
        }
        .compatibleGlassEffect(in: .circle, interactive: true, clear: true)
        #if os(visionOS)
        .disabled(true)
        .opacity(0)
        #else
        .disabled(isAd)
        .opacity(isAd ? 0.5 : 1.0)
        #endif
    }

    @ViewBuilder
    private var fullscreenButton: some View {
        Button {
            onEnterFullscreen()
            scheduleAutoHide()
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 16, weight: .medium))
                .frame(width: 40, height: 40)
        }
        .compatibleGlassEffect(in: .circle, interactive: true, clear: true)
        .disabled(isAd)
        .opacity(isAd ? 0.5 : 1.0)
    }

    @ViewBuilder
    private var centerControl: some View {
        Button {
            onTogglePlayPause()
            scheduleAutoHide()
        } label: {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 30, weight: .semibold))
                .frame(width: 72, height: 72)
                .contentTransition(.symbolEffect(.replace))
        }
        .compatibleGlassEffect(in: .circle, interactive: true, clear: true)
    }

    @ViewBuilder
    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button {
                onRewind()
                scheduleAutoHide()
            } label: {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 36, height: 36)
            }
            .disabled(isAd)
            .opacity(isAd ? 0.5 : 1.0)

            OverlaySeekBar(
                session: session,
                isAd: isAd,
                segments: segments,
                labelLayout: isPortraitVideo ? .hidden : .inline,
                onSeek: { time in
                    onSeek(time)
                    scheduleAutoHide()
                },
                onScrubbingChanged: { isScrubbing in
                    if isScrubbing {
                        hideTask?.cancel()
                    } else {
                        scheduleAutoHide()
                    }
                }
            )
            .tint(.white)

            Button {
                if isAd && isAdSkippable {
                    onSkipAd()
                } else {
                    onFastForward()
                }
                scheduleAutoHide()
            } label: {
                Image(systemName: isAd ? "forward.end.fill" : "goforward.10")
                    .font(.system(size: 18, weight: .medium))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 36, height: 36)
            }
            .disabled(isAd && !isAdSkippable)
            .opacity((isAd && !isAdSkippable) ? 0.5 : 1.0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .compatibleGlassEffect(in: .capsule, interactive: true, clear: true)
    }

    private var isPortraitVideo: Bool {
        videoAspectRatio < 1.0
    }

    private func toggleVisibility() {
        withAnimation(.smooth.speed(2.0)) {
            isVisible.toggle()
        }
        if isVisible {
            scheduleAutoHide()
        } else {
            hideTask?.cancel()
        }
    }

    private func scheduleAutoHide() {
        hideTask?.cancel()
        guard isPlaying else { return }
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth.speed(2.0)) {
                isVisible = false
            }
        }
    }
}

/// Reads `currentTime` and `duration` from the player session inside its own
/// body so periodic time updates only invalidate the seek bar, not the whole
/// overlay.
private struct OverlaySeekBar: View {

    let session: YouTubePlayerSession
    let isAd: Bool
    let segments: [(start: Double, end: Double)]
    let labelLayout: SeekBarLabelLayout
    let onSeek: (TimeInterval) -> Void
    let onScrubbingChanged: (Bool) -> Void

    var body: some View {
        SeekBarView(
            currentTime: session.currentTime,
            duration: session.duration,
            isDisabled: isAd,
            segments: segments,
            labelLayout: labelLayout,
            onSeek: onSeek,
            onScrubbingChanged: onScrubbingChanged
        )
    }
}
