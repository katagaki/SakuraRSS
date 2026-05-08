import SwiftUI

/// Liquid-Glass control overlay that sits on top of the video itself.
/// Tapping the video toggles visibility; an internal timer auto-hides
/// the controls a few seconds after the last interaction.
struct NewYouTubePlayerOverlayControls: View {

    enum TrailingAction {
        case enterFullscreen(() -> Void)
        case exitFullscreen(() -> Void)
    }

    let playback: NewYouTubePlaybackController
    let trailingAction: TrailingAction
    let sponsorSegments: [SponsorSegment]

    @State private var isVisible = true
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(.rect)
                .onTapGesture {
                    toggleVisibility()
                }

            if isVisible {
                GlassEffectContainer {
                    VStack(spacing: 0) {
                        topBar
                        Spacer(minLength: 4)
                        centerControl
                        Spacer(minLength: 4)
                        bottomBar
                    }
                    .padding(.horizontal, isFullscreen ? 32 : 8)
                    .padding(.vertical, isFullscreen ? 20 : 8)
                    .foregroundStyle(.white)
                    .transition(.opacity)
                }
            }
        }
        .onAppear { scheduleAutoHide() }
        .onChange(of: playback.isPlaying) { _, _ in scheduleAutoHide() }
    }

    @ViewBuilder
    private var topBar: some View {
        HStack {
            pictureInPictureButton
            Spacer()
            trailingActionButton
        }
    }

    @ViewBuilder
    private var pictureInPictureButton: some View {
        Button {
            playback.togglePictureInPicture()
            scheduleAutoHide()
        } label: {
            Image(systemName: playback.isPictureInPictureActive ? "pip.exit" : "pip.enter")
                .font(.system(size: 16, weight: .medium))
                .frame(width: 40, height: 40)
                .contentTransition(.symbolEffect(.replace))
        }
        .compatibleGlassEffect(in: .circle, interactive: true)
        #if os(visionOS)
        .disabled(true)
        .opacity(0)
        #else
        .disabled(!playback.isPictureInPicturePossible)
        .opacity(playback.isPictureInPicturePossible ? 1.0 : 0.5)
        #endif
    }

    @ViewBuilder
    private var trailingActionButton: some View {
        Button {
            invokeTrailingAction()
            scheduleAutoHide()
        } label: {
            Image(systemName: trailingActionSymbol)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 40, height: 40)
        }
        .compatibleGlassEffect(in: .circle, interactive: true)
    }

    @ViewBuilder
    private var centerControl: some View {
        Button {
            playback.togglePlayPause()
            scheduleAutoHide()
        } label: {
            Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 30, weight: .semibold))
                .frame(width: 72, height: 72)
                .contentTransition(.symbolEffect(.replace))
        }
        .compatibleGlassEffect(in: .circle, interactive: true)
    }

    @ViewBuilder
    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button {
                playback.rewind()
                scheduleAutoHide()
            } label: {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 36, height: 36)
            }

            SeekBarView(
                currentTime: playback.currentTime,
                duration: playback.duration,
                segments: sponsorSegments.map { (start: $0.startTime, end: $0.endTime) },
                labelLayout: .inline,
                onSeek: { time in
                    playback.seek(to: time)
                    scheduleAutoHide()
                }
            )
            .tint(.white)

            Button {
                playback.fastForward()
                scheduleAutoHide()
            } label: {
                Image(systemName: "goforward.10")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .compatibleGlassEffect(in: .capsule, interactive: true)
    }

    private var isFullscreen: Bool {
        if case .exitFullscreen = trailingAction { return true }
        return false
    }

    private var trailingActionSymbol: String {
        switch trailingAction {
        case .enterFullscreen: "arrow.up.left.and.arrow.down.right"
        case .exitFullscreen: "arrow.down.right.and.arrow.up.left"
        }
    }

    private func invokeTrailingAction() {
        switch trailingAction {
        case .enterFullscreen(let action), .exitFullscreen(let action):
            action()
        }
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
        guard playback.isPlaying else { return }
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth.speed(2.0)) {
                isVisible = false
            }
        }
    }
}
