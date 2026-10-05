import Hanami
import SwiftUI

/// Covers the floating video so the page never takes the mouse: a click
/// plays or pauses, a drag moves the panel, and hovering shows Liquid Glass
/// controls.
struct YouTubePictureInPictureControls: View {

    let session: YouTubePlayerSession
    let onDragChanged: () -> Void
    let onDragEnded: () -> Void
    let onReturn: () -> Void
    let onClose: () -> Void
    @State private var isHovering = false

    var body: some View {
        Color.clear
            .contentShape(.rect)
            .onTapGesture { session.togglePlayPause() }
            .gesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { _ in onDragChanged() }
                    .onEnded { _ in onDragEnded() }
            )
            .overlay {
                if isHovering {
                    controls
                        .transition(.opacity)
                }
            }
            .onHover { hovering in
                withAnimation(.smooth(duration: 0.2)) { isHovering = hovering }
            }
            .onChange(of: session.currentArticle == nil) { _, hasStopped in
                if hasStopped { onClose() }
            }
    }

    private var controls: some View {
        GlassEffectContainer {
            VStack {
                HStack {
                    Button(action: onClose) { Image(systemName: "xmark") }
                    Spacer()
                    Button(action: onReturn) { Image(systemName: "pip.exit") }
                        .help(String(localized: "Player.ShowVideo", table: "Mac"))
                }
                Spacer()
                HStack(spacing: 14) {
                    Button { YouTubePlaybackCommands.seek(session.webView, by: -10) } label: {
                        Image(systemName: "gobackward.10")
                    }
                    Button { session.togglePlayPause() } label: {
                        Image(systemName: session.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22))
                            .frame(width: 32, height: 32)
                    }
                    Button { YouTubePlaybackCommands.seek(session.webView, by: 10) } label: {
                        Image(systemName: "goforward.10")
                    }
                }
                Spacer()
            }
            .padding(10)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .font(.system(size: 13, weight: .semibold))
        .background(Color.black.opacity(0.2).allowsHitTesting(false))
    }
}
